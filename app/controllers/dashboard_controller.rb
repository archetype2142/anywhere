class DashboardController < ApplicationController
  # Skip CSRF for API endpoints
  skip_before_action :verify_authenticity_token, only: [:retry_failed_order, :process_pending_charge, 
                                                        :retry_all_failed_orders, :process_all_pending_charges,
                                                        :refresh_merchant_stripe_account, :trigger_database_purge]
  
  def index
    # Pagination parameters
    @page = params[:page] || 1
    @per_page = params[:per_page] || 10
    
    # Fetch data with pagination - avoid caching ActiveRecord objects directly
    @orders = Order.includes(:merchant, :parent_relationships, :child_relationships, 
                            :parent_orders, :child_orders)
                  .order(created_at: :desc).page(@page).per(@per_page)
    @merchants = Merchant.order(created_at: :desc).page(@page).per(@per_page)
    @pending_charges = PendingCharge.order(created_at: :desc).page(@page).per(@per_page)
    @failed_orders = Order.where(status: :failed).order(created_at: :desc).page(@page).per(@per_page)
    
    # Stats with caching - use low-level caching for simple values
    @total_orders = Rails.cache.fetch("total_orders_count", expires_in: 15.minutes) do
      Order.count
    end
    
    @total_merchants = Rails.cache.fetch("total_merchants_count", expires_in: 30.minutes) do
      Merchant.count
    end
    
    @total_pending_charges = Rails.cache.fetch("total_pending_charges_count", expires_in: 5.minutes) do
      PendingCharge.count
    end
    
    @total_failed_orders = Rails.cache.fetch("total_failed_orders_count", expires_in: 5.minutes) do
      Order.where(status: :failed).count
    end
    
    @total_amount = Rails.cache.fetch("total_amount_sum", expires_in: 15.minutes) do
      Order.sum(:amount)
    end
    
    @total_commission = Rails.cache.fetch("total_commission_sum", expires_in: 15.minutes) do
      Order.sum(:commission_amount)
    end
    
    @total_payout = Rails.cache.fetch("total_payout_sum", expires_in: 15.minutes) do
      Order.sum(:payout_amount)
    end
    
    # For complex objects like hashes, use JSON serialization
    @orders_by_status = Rails.cache.fetch("orders_by_status_counts", expires_in: 15.minutes) do
      Order.group(:status).count.to_h
    end
    
    # Add stats for gym bookings
    @total_gym_bookings = Rails.cache.fetch("total_gym_bookings_count", expires_in: 15.minutes) do
      Order.where(order_type: :gym_booking).count
    end
    
    @total_gym_booking_amount = Rails.cache.fetch("total_gym_booking_amount", expires_in: 15.minutes) do
      Order.where(order_type: :gym_booking).sum(:amount)
    end
    
    # Get last database purge timestamp
    @last_database_purge = Rails.cache.fetch("last_database_purge_timestamp")
    @last_database_purge_error = Rails.cache.fetch("last_database_purge_error")
  end
  
  def retry_failed_order
    order = Order.find(params[:id])

    order_data = AnywhereClubsApi.get_order_details(order.job_id)

    if order.status == 'failed'
      ProcessOrderJob.perform_later(order_data)
      flash[:success] = "Order #{order.job_id} has been queued for retry."
    else
      flash[:error] = "Only failed orders can be retried."
    end
    redirect_to dashboard_path
  end
  
  def retry_all_failed_orders
    failed_orders = Order.where(status: :failed)
    count = failed_orders.count
    
    if count > 0
      failed_orders.find_each do |order|
        order_data = AnywhereClubsApi.get_order_details(order.job_id)
        ProcessOrderJob.perform_later(order_data)
      end
      flash[:success] = "#{count} failed orders have been queued for retry."
    else
      flash[:notice] = "No failed orders to retry."
    end
    
    redirect_to dashboard_path
  end
  
  def process_pending_charge
    pending_charge = PendingCharge.find(params[:id])
    
    # begin
      ::ProcessPendingChargesJob.perform_now()
      # flash[:notice] = "Successfully processed pending charge #{pending_charge.charge_id}"
    # rescue => e
      # flash[:alert] = "Failed to process pending charge: #{e.message}"
    # end
    
    invalidate_dashboard_cache
    
    redirect_to dashboard_index_path
  end
  
  def process_all_pending_charges
    pending_charges = PendingCharge.all
    
    count = 0
    pending_charges.each do |charge|
      begin
        ::ProcessPendingChargesJob.perform_now()
        count += 1
      rescue => e
        Rails.logger.error("Failed to process pending charge #{charge.id}: #{e.message}")
      end
    end
    
    flash[:notice] = "Successfully processed #{count} out of #{pending_charges.count} pending charges"
    
    invalidate_dashboard_cache
    
    redirect_to dashboard_index_path
  end
  
  def refresh_merchant_stripe_account
    merchant = Merchant.find(params[:id])
    
    if merchant.fetch_and_update_stripe_account
      flash[:notice] = "Successfully refreshed Stripe account for merchant #{merchant.name}"
    else
      flash[:alert] = "Failed to refresh Stripe account for merchant #{merchant.name}"
    end
    
    invalidate_dashboard_cache
    
    redirect_to dashboard_index_path
  end
  
  def trigger_database_purge
    # Enqueue the database purge job
    DatabasePurgeJob.perform_later
    
    flash[:notice] = "Database purge has been scheduled and will run in the background"
    redirect_to dashboard_path
  end
  
  private
  
  def invalidate_dashboard_cache
    # Clear specific caches
    Rails.cache.delete_matched("orders_page_*")
    Rails.cache.delete_matched("failed_orders_page_*")
    Rails.cache.delete_matched("pending_charges_page_*")
    Rails.cache.delete_matched("merchants_page_*")
    
    # Clear stats caches
    Rails.cache.delete("total_orders_count")
    Rails.cache.delete("total_merchants_count")
    Rails.cache.delete("total_pending_charges_count")
    Rails.cache.delete("total_failed_orders_count")
    Rails.cache.delete("total_amount_sum")
    Rails.cache.delete("total_commission_sum")
    Rails.cache.delete("total_payout_sum")
    Rails.cache.delete("orders_by_status_counts")
  end
end
