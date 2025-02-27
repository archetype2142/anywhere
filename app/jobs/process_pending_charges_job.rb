class ProcessPendingChargesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting to process pending charges")
    
    # Process all pending charges
    PendingCharge.process_all
    
    Rails.logger.info("Finished processing pending charges")
  end
end
