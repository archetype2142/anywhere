class ProcessMerchantJob < ApplicationJob
  queue_as :default

  def perform(merchant_data)
    # Create or update the merchant
    merchant = Merchant.create_from_webhook(merchant_data)
    
    if merchant
      Rails.logger.info("Successfully processed merchant: #{merchant.id} (#{merchant.name})")
    else
      Rails.logger.error("Failed to process merchant from webhook data")
    end
  end
end
