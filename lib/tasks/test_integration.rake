namespace :test do
  desc "Test processing an order with a sample payload"
  task process_order: :environment do
    # Sample order data based on the provided example
    order_data = {
      "marketplace_user_id" => "1679223",
      "merchant_id" => "1697739",
      "order_id" => "7446451",
      "total_amount" => 2.08,
      "commission_amount" => 0.5,
      "merchant_earning" => 1.58,
      "currency_code" => "USD",
      "transaction_id" => "ch_3Qwj1JB3SQzmJYpR1aLo35Ef",
      "merchant_name" => "Test",
      "merchant_email" => "malhotraritwick2011@gmail.com"
    }

    puts "Creating or updating order..."
    order = Order.create_from_webhook(order_data)

    if order
      puts "Order created successfully: #{order.id} (#{order.order_id})"
      puts "Processing payout..."
      
      if order.process_payout
        puts "Payout processed successfully!"
      else
        puts "Failed to process payout. Check logs for details."
      end
    else
      puts "Failed to create order. Check logs for details."
    end
  end

  desc "Test fetching merchant details"
  task fetch_merchant: :environment do
    merchant_id = ENV['TEST_MERCHANT_ID'] || "1679223"
    
    puts "Fetching merchant details for ID: #{merchant_id}"
    merchant_details = AnywhereClubsApi.get_merchant_details(merchant_id)
    
    if merchant_details
      puts "Merchant details fetched successfully:"
      puts JSON.pretty_generate(merchant_details)
    else
      puts "Failed to fetch merchant details. Check logs for details."
    end
  end

  desc "Test webhook simulation for order creation"
  task simulate_order_webhook: :environment do
    # Sample webhook payload based on the provided example
    webhook_payload = {
      "webhook_event" => {
        "entity" => "ORDER",
        "type" => "CREATE",
        "event" => "ORDER_PLACED",
        "event_id" => 24021681
      },
      "marketplace_user_id" => "1679223",
      "merchant_id" => "1697739",
      "order_id" => "7446451",
      "total_amount" => 2.08,
      "commission_amount" => 0.5,
      "merchant_earning" => 1.58,
      "currency_code" => "USD",
      "transaction_id" => "ch_3Qwj1JB3SQzmJYpR1aLo35Ef",
      "merchant_name" => "Test",
      "merchant_email" => "malhotraritwick2011@gmail.com"
    }

    puts "Simulating order webhook..."
    ProcessOrderJob.perform_now(webhook_payload)
    puts "Webhook simulation completed."
  end
end
