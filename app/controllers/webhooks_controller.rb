class WebhooksController < ApplicationController
  # Skip CSRF protection for webhooks
  skip_before_action :verify_authenticity_token

  # Stripe webhook endpoint
  def stripe
    # Verify the webhook signature
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )

    rescue JSON::ParserError => e
      # Invalid payload
      render json: { error: 'Invalid payload' }, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      render json: { error: 'Invalid signature' }, status: 400
      return
    end

    # Handle the event
    case event.type
    when 'charge.succeeded'
      # Payment was successful
      charge = event.data.object
      Rails.logger.info("Stripe charge succeeded: #{charge.id}")
      
      # Extract order ID and job ID from description if possible
      order_id = nil
      job_id = nil
      if charge.description.present?
        # Try to match "Order #24022138" format
        order_match = charge.description.match(/Order #(\d+)/)
        if order_match
          job_id = order_match[1]
        end
        
        # Try to match "Customer Order #24022138" format
        customer_order_match = charge.description.match(/Customer Order #(\d+)/)
        if customer_order_match
          job_id = customer_order_match[1]
        end
      end
      
      # Look for an existing order with this transaction ID
      order = Order.find_by(transaction_id: charge.id)
      
      if order
        # Order exists, process the payment
        Rails.logger.info("Found order job_id: #{order.job_id}, order_id: #{order.order_id} for charge #{charge.id}, processing payment")
        order.process_payout
      else
        # Order doesn't exist yet, store the charge for later processing
        Rails.logger.info("No order found for charge #{charge.id}, storing as pending charge")
        
        # Store the charge details
        PendingCharge.create(
          charge_id: charge.id,
          amount: charge.amount / 100.0, # Convert from cents
          currency: charge.currency,
          metadata: {
            order_id: order_id,
            job_id: job_id,
            description: charge.description,
            customer: charge.customer
          }.to_json
        )
      end
    when 'payment_intent.succeeded'
      # Payment intent was successful
      payment_intent = event.data.object
      Rails.logger.info("Stripe payment intent succeeded: #{payment_intent.id}")
      
      # Check if this is a payout payment intent
      order = Order.find_by(stripe_transfer_id: payment_intent.id)
      if order
        order.update(status: :paid)
        Rails.logger.info("Updated order #{order.job_id || order.order_id} status to paid")
      end
    when 'transfer.created', 'transfer.updated'
      # Transfer to connected account was created or updated
      transfer = event.data.object
      order = Order.find_by(stripe_transfer_id: transfer.id)
      if order
        order.update(status: transfer.status == 'paid' ? :paid : :failed)
      end
    else
      # Unexpected event type
      Rails.logger.info("Unhandled event type: #{event.type}")
    end

    render json: { received: true }
  end

  # AnywhereClubs webhook endpoint
  def anywhere_clubs
    # Verify the webhook signature if needed
    # For now, we'll assume the webhook is valid

    # Parse the webhook payload
    payload = params.permit!.to_h
    
    # Check for webhook_event
    if payload['webhook_event'].blank?
      render json: { error: 'Invalid payload' }, status: 400
      return
    end

    # Extract the webhook event
    webhook_event = payload['webhook_event']
    entity = webhook_event['entity']
    event_type = webhook_event['type']
    event = webhook_event['event']

    # Handle the event based on entity and type
    case [entity, event_type, event]
    when ['MERCHANT', 'CREATE', 'MERCHANT_CREATED'], ['MERCHANT', 'UPDATE', 'MERCHANT_UPDATED']
      # Merchant created or updated
      merchant_data = payload
      ProcessMerchantJob.perform_later(merchant_data)
    when ['ORDER', 'CREATE', 'ORDER_PLACED']
      # Order created
      order_data = payload
      ProcessOrderJob.perform_later(order_data)
    else
      # Unexpected event
      Rails.logger.info("Unhandled AnywhereClubs event: #{entity}/#{event_type}/#{event}")
    end

    render json: { received: true }
  end
end
