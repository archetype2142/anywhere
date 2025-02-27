class ProcessOrderJob < ApplicationJob
  queue_as :default

  def perform(order_data)
    # Create or update the order
    # Remove byebug for production
    # byebug
  
    order = Order.create_from_webhook(order_data)
    
    if order
      Rails.logger.info("Successfully processed order: #{order.id} (job_id: #{order.job_id}, order_id: #{order.order_id})")
      
      # Process the payout
      if order.process_payout
        Rails.logger.info("Successfully processed payout for order: #{order.id} (job_id: #{order.job_id})")
        
        # If this is a trainer order and we have commission, check if we need to create a gym booking
        if order.merchant&.business_type == 'trainer' && order.commission_amount.to_f > 0
          create_gym_booking_if_needed(order, order_data)
        end
      else
        Rails.logger.error("Failed to process payout for order: #{order.id} (job_id: #{order.job_id})")
      end
    else
      Rails.logger.error("Failed to process order from webhook data")
    end
  end
  
  private
  
  def create_gym_booking_if_needed(order, order_data)
    # Check if the order has gym booking information in the checkout template
    gym_id = nil
    gym_booking_details = {}
    
    if order_data['checkout_template'].present?
      order_data['checkout_template'].each do |field|
        if field['label'].to_s.include?('gym_id') && field['value'].present?
          gym_id = field['value'].to_s
          Rails.logger.info("Found gym_id: #{gym_id} for order: #{order.job_id}")
        end
        
        # Collect other gym booking details
        if field['label'].to_s.start_with?('gym_') && field['value'].present?
          key = field['label'].to_s.sub('gym_', '')
          gym_booking_details[key] = field['value']
        end
      end
    end
    
    # If we have a gym_id, create a gym booking order
    if gym_id.present?
      Rails.logger.info("Creating gym booking for order: #{order.job_id} with gym_id: #{gym_id}")
      
      # Find the gym merchant
      gym = Merchant.find_by(marketplace_user_id: gym_id)
      
      unless gym
        # Try to fetch gym details from API
        gym_details = AnywhereClubsApi.get_merchant_details(gym_id)
        
        if gym_details
          gym = Merchant.create(
            marketplace_user_id: gym_id,
            name: gym_details['name'] || "Gym #{gym_id}",
            email: gym_details['email'],
            business_type: :gym
          )
          
          if gym.save
            Rails.logger.info("Created gym merchant: #{gym.id} (#{gym.name})")
            gym.fetch_and_update_stripe_account
          else
            Rails.logger.error("Failed to create gym merchant: #{gym.errors.full_messages.join(', ')}")
            return
          end
        else
          Rails.logger.error("Could not fetch gym details for gym_id: #{gym_id}")
          return
        end
      end
      
      # Calculate gym booking amount (use commission from trainer order)
      gym_booking_amount = order.commission_amount
      
      # Create a new order for the gym
      gym_order = Order.new(
        merchant: gym,
        order_id: "GYM-#{order.order_id}",
        job_id: "GYM-#{order.job_id}",
        amount: gym_booking_amount,
        status: :pending,
        currency_code: order.currency_code,
        order_type: :gym_booking,
        parent_order_job_id: order.job_id
      )
      
      if gym_order.save
        Rails.logger.info("Created gym booking order: #{gym_order.id} (job_id: #{gym_order.job_id})")
        
        # Create relationship between orders
        relationship = RelatedOrder.create(
          parent_order: order,
          child_order: gym_order,
          relationship_type: :gym_booking
        )
        
        if relationship.persisted?
          Rails.logger.info("Created relationship between orders: #{order.job_id} -> #{gym_order.job_id}")
          
          # Process payout for gym order
          if gym_order.process_payout
            Rails.logger.info("Successfully processed payout for gym order: #{gym_order.id} (job_id: #{gym_order.job_id})")
          else
            Rails.logger.error("Failed to process payout for gym order: #{gym_order.id} (job_id: #{gym_order.job_id})")
          end
        else
          Rails.logger.error("Failed to create relationship between orders: #{relationship.errors.full_messages.join(', ')}")
        end
      else
        Rails.logger.error("Failed to create gym booking order: #{gym_order.errors.full_messages.join(', ')}")
      end
    end
  end
end
