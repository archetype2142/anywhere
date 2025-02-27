class DatabasePurgeJob < ApplicationJob
  queue_as :default

  def perform
    cutoff_date = 1.minute.ago
  
    Rails.logger.info "Starting weekly database purge for data older than #{cutoff_date}"

    # Debug logs remain the same
    Rails.logger.info "DEBUG - Total counts before purge:"
    Rails.logger.info "Orders: #{Order.count}"
    Rails.logger.info "Merchants: #{Merchant.count}"
    Rails.logger.info "PendingCharges: #{PendingCharge.count}"
    Rails.logger.info "RelatedOrders: #{RelatedOrder.count}"

    begin
      ActiveRecord::Base.transaction do
        # First, delete old related_orders
        old_related_orders = RelatedOrder.joins("INNER JOIN orders parent_orders ON parent_orders.id = related_orders.parent_order_id")
                                       .joins("INNER JOIN orders child_orders ON child_orders.id = related_orders.child_order_id")
                                       .where("parent_orders.created_at < ? OR child_orders.created_at < ?", cutoff_date, cutoff_date)

        Rails.logger.info "DEBUG - Found #{old_related_orders.count} old related orders to delete"
        Rails.logger.info "DEBUG - RelatedOrder IDs to delete: #{old_related_orders.pluck(:id)}"
        
        old_related_orders_count = old_related_orders.count
        old_related_orders.destroy_all
        Rails.logger.info "Purged #{old_related_orders_count} old related orders"

        # Now delete all old orders without worrying about related orders
        old_orders = Order.where('created_at < ?', cutoff_date)
        
        Rails.logger.info "DEBUG - Found #{old_orders.count} old orders to delete"
        Rails.logger.info "DEBUG - Order IDs to delete: #{old_orders.pluck(:id)}"
        Rails.logger.info "DEBUG - Order created_at dates: #{old_orders.pluck(:created_at)}"

        old_orders_count = old_orders.count
        old_orders.destroy_all

        Rails.logger.info "Purged #{old_orders_count} old orders"
  
        # The rest of your code remains the same for merchants and pending charges
        old_merchants = Merchant.left_joins(:orders).where(orders: { id: nil })
        Rails.logger.info "DEBUG - Found #{old_merchants.count} merchants with no orders to delete"
        Rails.logger.info "DEBUG - Merchant IDs to delete: #{old_merchants.pluck(:id)}"
        
        old_merchants_count = old_merchants.count
        old_merchants.destroy_all
        Rails.logger.info "Purged #{old_merchants_count} merchants with no orders"
  
        old_pending_charges = PendingCharge.where('created_at < ?', cutoff_date)
        Rails.logger.info "DEBUG - Found #{old_pending_charges.count} old pending charges to delete"
        Rails.logger.info "DEBUG - PendingCharge IDs to delete: #{old_pending_charges.pluck(:id)}"
        Rails.logger.info "DEBUG - PendingCharge created_at dates: #{old_pending_charges.pluck(:created_at)}"
        
        old_pending_charges_count = old_pending_charges.count
        old_pending_charges.destroy_all
        Rails.logger.info "Purged #{old_pending_charges_count} old pending charges"
      end

      # Clear Rails cache
      Rails.cache.clear
      Rails.logger.info "Cleared Rails cache"

      # Store the last purge timestamp in Redis
      timestamp = Time.current.to_s
      Rails.logger.info "Setting last_database_purge_timestamp to #{timestamp}"
      
      # Use both Rails.cache and direct Redis storage to ensure it works in all environments
      Rails.cache.write("last_database_purge_timestamp", timestamp, expires_in: 1.year)

      # Direct Redis storage if Redis is available
      if defined?(Redis) && Rails.application.config.respond_to?(:redis_url)
        redis = Redis.new(url: Rails.application.config.redis_url)
        redis.set("last_database_purge_timestamp", timestamp)
        redis.expire("last_database_purge_timestamp", 1.year.to_i)
        Rails.logger.info "Stored timestamp in Redis directly"
      end

      # Log completion
      Rails.logger.info "Weekly database purge completed"
    rescue => e
      Rails.logger.error "Database purge failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Store the error in Redis for display in the dashboard
      error_data = { 
        message: e.message, 
        time: Time.current.to_s,
        backtrace: e.backtrace.first(5)
      }.to_json
      
      Rails.cache.write("last_database_purge_error", error_data, expires_in: 1.week)
      
      # Direct Redis storage if Redis is available
      if defined?(Redis) && Rails.application.config.respond_to?(:redis_url)
        redis = Redis.new(url: Rails.application.config.redis_url)
        redis.set("last_database_purge_error", error_data)
        redis.expire("last_database_purge_error", 1.week.to_i)
      end
      
      # Re-raise the error to ensure job failure is properly recorded
      raise
    end
  end
end
