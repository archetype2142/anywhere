class PendingCharge < ApplicationRecord
  validates :charge_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  
  # Find and process any pending charges for a given order
  def self.process_for_order(order)
    # Look for pending charges with matching transaction ID
    pending_charge = find_by(charge_id: order.transaction_id)
    
    if pending_charge
      Rails.logger.info("Found pending charge #{pending_charge.charge_id} for order job_id: #{order.job_id}")
      
      # Process the payout
      if order.process_payout
        Rails.logger.info("Successfully processed payout for order: #{order.id} (job_id: #{order.job_id}) from pending charge")
        # Delete the pending charge
        pending_charge.destroy
        return true
      else
        Rails.logger.error("Failed to process payout for order: #{order.id} (job_id: #{order.job_id}) from pending charge")
        return false
      end
    end
    
    false
  end
  
  # Try to process a pending charge by fetching order details from the API
  def process
    # Extract order ID from metadata if available
    metadata = JSON.parse(self.metadata) rescue {}
    job_id = metadata['job_id']
    order_id = job_id

    # If we don't have an order ID or job_id, we can't process this charge yet
    return false unless job_id.present?
    
    # Try to fetch order details from the API
    order_details = AnywhereClubsApi.get_order_details(job_id)
    
    if order_details.present?
      # Create an order data hash that matches the webhook format
      order_data = {
        'marketplace_user_id' => order_details['merchant_id'],
        'merchant_id' => order_details['merchant_id'],
        'order_id' => job_id,
        'job_id' => job_id || order_details['job_id'],
        'total_amount' => order_details['total_amount'] || self.amount,
        'currency_code' => self.currency,
        'transaction_id' => self.charge_id,
        'merchant_name' => order_details['merchant_name'],
        'merchant_email' => order_details['merchant_email']
      }
      
      # Create or update the order
      order = Order.create_from_webhook(order_data)
      
      if order
        Rails.logger.info("Successfully created order job_id: #{order.job_id}, from pending charge #{self.charge_id}")
        
        # Let the order calculate commission based on merchant settings
        order.calculate_commission
        
        return true
      else
        Rails.logger.error("Failed to create order from pending charge #{self.charge_id}")
        return false
      end
    else
      Rails.logger.info("Could not fetch order details for order ID #{order_id} from pending charge #{self.charge_id}")
      return false
    end
  end
  
  # Process all pending charges
  def self.process_all
    pending_charges = PendingCharge.all

    pending_charges.each do |pending_charge|
      begin
        if pending_charge.process
          Rails.logger.info("Successfully processed pending charge: #{pending_charge.charge_id}")
          pending_charge.destroy
        end
      rescue => e
        Rails.logger.error("Error processing pending charge #{pending_charge.charge_id}: #{e.message}")
      end
    end
  end
end
