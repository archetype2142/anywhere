class Order < ApplicationRecord
  belongs_to :merchant

  # Fix deprecation warning by using positional arguments
  enum :status, [:pending, :processing, :paid, :failed, :canceled]

  validates :job_id, presence: true, uniqueness: true
  validates :order_id, presence: true

  # Add relationships for related orders
  has_many :parent_relationships, class_name: 'RelatedOrder', foreign_key: 'parent_order_id', dependent: :destroy
  has_many :child_relationships, class_name: 'RelatedOrder', foreign_key: 'child_order_id', dependent: :destroy
  
  has_many :child_orders, through: :parent_relationships, source: :child_order
  has_many :parent_orders, through: :child_relationships, source: :parent_order

  # Add order type to distinguish between regular orders and gym bookings
  enum :order_type, [:regular, :gym_booking], default: :regular

  # Create or update an order from webhook data
  def self.create_from_webhook(order_data)
    # Extract the necessary data from the webhook payload
    marketplace_user_id = order_data['marketplace_user_id']
    merchant_id = order_data['merchant_id']
    order_id = order_data['order_id']
    job_id = order_data['job_id']
    total_amount = order_data['total_amount'].to_f
    commission_amount = order_data['commission_amount'].to_f if order_data['commission_amount']
    merchant_earning = order_data['merchant_earning'].to_f if order_data['merchant_earning']
    currency_code = order_data['currency_code']
    transaction_id = order_data['transaction_id']

    # Check if this is a gym booking order by looking for the customer_order_id_number in checkout_template
    parent_order_job_id = nil
    order_type = :regular
    
    if order_data['checkout_template'].present?
      order_data['checkout_template'].each do |field|
        if field['label'].to_s.include?('customer_order_id_number') && field['value'].present?
          parent_order_job_id = field['value'].to_s
          order_type = :gym_booking
          Rails.logger.info("Detected gym booking order with parent order job_id: #{parent_order_job_id}")
          break
        end
      end
    end

    # Find the merchant
    merchant = if order_data['business_type'] == 2
      Merchant.find_by(anywhere_merchant_id: merchant_id.to_s)
    else
      Merchant.find_by(marketplace_user_id: marketplace_user_id.to_s)      
    end

    # If merchant doesn't exist, create it on the fly
    unless merchant
      Rails.logger.info("Merchant not found for marketplace_user_id: #{marketplace_user_id}, creating on the fly")
      
      # Get merchant details from the API
      if order_data['business_type'] == 2
        merchant_details = AnywhereClubsApi.get_merchant_details(merchant_id)
      else
        merchant_details = AnywhereClubsApi.get_merchant_details(marketplace_user_id)
      end

      if merchant_details
        # Create the merchant
        merchant = Merchant.new(
          marketplace_user_id: marketplace_user_id.to_s,
          anywhere_merchant_id: merchant_id.to_s,
          name: merchant_details['name'] || order_data['merchant_name'] || "Merchant #{marketplace_user_id}",
          email: merchant_details['email'] || order_data['merchant_email'],
          business_type: order_data['business_type'] || :unknown
        )

        if merchant.save
          # Fetch Stripe account ID and commission settings
          merchant.fetch_and_update_stripe_account
          merchant.fetch_and_update_commission_settings
          Rails.logger.info("Successfully created merchant on the fly: #{merchant.id} (#{merchant.name}), business_type: #{merchant.business_type}")
        else
          Rails.logger.error("Failed to create merchant on the fly: #{merchant.errors.full_messages.join(', ')}")
          return nil
        end
      else
        # If we couldn't get merchant details from the API, create with minimal info from the order
        merchant = Merchant.new(
          marketplace_user_id: marketplace_user_id.to_s,
          anywhere_merchant_id: merchant_id.to_s,
          name: order_data['merchant_name'] || "Merchant #{marketplace_user_id}",
          email: order_data['merchant_email'],
          business_type: order_data['business_type'] || :unknown
        )
        
        if merchant.save
          Rails.logger.info("Created merchant with minimal info: #{merchant.id} (#{merchant.name}), business_type: #{merchant.business_type}")
          # Still try to fetch Stripe account ID and commission settings
          merchant.fetch_and_update_stripe_account
          merchant.fetch_and_update_commission_settings
        else
          Rails.logger.error("Failed to create merchant with minimal info: #{merchant.errors.full_messages.join(', ')}")
          return nil
        end
      end
    else
      # Always refresh commission settings from the API
      merchant.fetch_and_update_commission_settings
    end

    # Create or update the order
    order = Order.find_or_initialize_by(job_id: job_id.to_s)
    
    attributes = {
      merchant: merchant,
      order_id: order_id.to_s,
      amount: total_amount,
      status: :pending,
      currency_code: currency_code,
      transaction_id: transaction_id,
      order_type: order_type,
      parent_order_job_id: parent_order_job_id
    }
    
    # Only set commission and payout if provided
    attributes[:commission_amount] = commission_amount if commission_amount
    attributes[:payout_amount] = merchant_earning if merchant_earning
    
    order.assign_attributes(attributes)

    if order.save
      # Check if there's a pending charge for this transaction
      if transaction_id.present?
        PendingCharge.process_for_order(order)
      end
      
      # Calculate commission if not provided
      if !order_data['commission_amount'] || !order_data['merchant_earning']
        order.calculate_commission
      end
      
      # If this is a gym booking order, link it to the parent order
      if order.order_type == 'gym_booking' && order.parent_order_job_id.present?
        parent_order = Order.find_by(job_id: order.parent_order_job_id)
        
        if parent_order
          # Create the relationship
          RelatedOrder.create(
            parent_order: parent_order,
            child_order: order,
            relationship_type: :gym_booking
          )
          Rails.logger.info("Linked gym booking order #{order.job_id} to parent order #{parent_order.job_id}")
        else
          Rails.logger.warn("Parent order #{order.parent_order_job_id} not found for gym booking order #{order.job_id}")
        end
      end
      
      order
    else
      Rails.logger.error("Failed to save order: #{order.errors.full_messages.join(', ')}")
      nil
    end
  end

  # Process the payout for this order
  def process_payout
    return false if status != 'pending' || stripe_transfer_id.present?
    
    # Ensure merchant has a Stripe account ID
    if merchant.stripe_account_id.blank?
      merchant.fetch_and_update_stripe_account
      
      if merchant.stripe_account_id.blank?
        update(status: :failed)
        Rails.logger.error("Failed to process payout for order #{job_id}: Merchant has no Stripe account ID")
        return false
      end
    end

    # Ensure we have the latest commission settings
    merchant.fetch_and_update_commission_settings

    # Calculate commission if not already set
    if commission_amount.nil? || commission_amount.zero?
      calculate_commission
    end

    # Try different payout methods in order
    result = nil
    
    # First try direct payment intent
    begin
      result = StripeService.transfer_to_connected_account(self)
    rescue => e
      Rails.logger.error("Failed to create payment intent: #{e.message}")
    end
    
    # If that fails, try payout
    if result.nil?
      begin
        result = StripeService.payout_to_connected_account(self)
      rescue => e
        Rails.logger.error("Failed to create payout: #{e.message}")
      end
    end
    
    result.present?
  end
  
  # Calculate commission based on merchant's commission settings
  def calculate_commission
    # Get the merchant's commission settings
    commission_settings = merchant.commission_settings.to_a
    
    if commission_settings.empty?
      # If no commission settings, use default 10%
      self.commission_amount = (amount * 0.1).round(2)
      self.payout_amount = amount - self.commission_amount
    else
      # Convert ActiveRecord objects to hashes for the StripeService
      settings_for_calculation = commission_settings.map do |setting|
        {
          'minimum_order_value' => setting.minimum_order_value,
          'maximum_order_value' => setting.maximum_order_value,
          'commission_value' => setting.commission_value,
          'commission_type' => setting.commission_type == 'fixed' ? 0 : 1,
          'is_default' => setting.is_default ? 1 : 0,
          'delivery_type' => setting.delivery_type
        }
      end
      
      # Calculate commission
      self.commission_amount = StripeService.calculate_commission(amount, settings_for_calculation)
      self.payout_amount = amount - self.commission_amount
    end
    
    save
  end
end
