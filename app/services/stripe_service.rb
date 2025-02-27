class StripeService
  def self.calculate_commission(order_amount, commission_settings)
    # Find the applicable commission setting based on order amount
    applicable_setting = commission_settings.find do |setting|
      # Check if order amount is within the range
      in_range = if setting['minimum_order_value'].to_f > 0 || setting['maximum_order_value'].to_f > 0
        (setting['minimum_order_value'].to_f..setting['maximum_order_value'].to_f).cover?(order_amount)
      else
        false
      end
      
      # Check if it's a default setting with 0 min/max
      is_default = setting['is_default'] == 1 && 
                   setting['minimum_order_value'].to_f == 0 && 
                   setting['maximum_order_value'].to_f == 0
      
      in_range || is_default
    end

    return 0 unless applicable_setting

    if applicable_setting['commission_type'] == 0 # Fixed
      applicable_setting['commission_value'].to_f
    else # Percentage
      (order_amount * applicable_setting['commission_value'].to_f / 100).round(2)
    end
  end

  def self.transfer_to_connected_account(order)
    return if order.stripe_transfer_id.present? || order.payout_amount <= 0

    begin
      # Instead of using Transfer which requires available balance,
      # create a new charge that directly pays out to the connected account
      charge = Stripe::PaymentIntent.create({
        amount: (order.payout_amount * 100).to_i, # Convert to cents
        currency: order.currency_code&.downcase || 'usd',
        payment_method_types: ['card'],
        payment_method: 'pm_card_visa', # Use a test payment method
        confirm: true,
        on_behalf_of: order.merchant.stripe_account_id,
        transfer_data: {
          destination: order.merchant.stripe_account_id,
        },
        description: "#{order.merchant.trainer? ? '[Trainer]: ' : '[Gym] '} Payout for Order ##{order.job_id || order.order_id}, #{order.merchant.name}",
        metadata: {
          order_id: order.order_id,
          job_id: order.job_id
        }
      })

      order.update(stripe_transfer_id: charge.id, status: :paid)
      charge
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to transfer to connected account: #{e.message}")
      order.update(status: :failed)
      nil
    end
  end
  
  def self.payout_to_connected_account(order)
    return if order.stripe_transfer_id.present? || order.payout_amount <= 0

    begin
      # Create a payout to the connected account's default bank account
      # This requires the connected account to have a bank account set up
      payout = Stripe::Payout.create(
        {
          amount: (order.payout_amount * 100).to_i, # Convert to cents
          currency: order.currency_code&.downcase || 'usd',
          description: "Payout for Order ##{order.job_id || order.order_id}",
          metadata: {
            order_id: order.order_id,
            job_id: order.job_id
          }
        },
        { stripe_account: order.merchant.stripe_account_id }
      )

      order.update(stripe_transfer_id: payout.id, status: :paid)
      payout
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to create payout to connected account: #{e.message}")
      order.update(status: :failed)
      nil
    end
  end
  
  def self.retrieve_charge(charge_id)
    begin
      Stripe::Charge.retrieve(charge_id)
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to retrieve charge #{charge_id}: #{e.message}")
      nil
    end
  end
end
