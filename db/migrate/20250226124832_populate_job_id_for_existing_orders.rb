class PopulateJobIdForExistingOrders < ActiveRecord::Migration[7.2]
  def up
    # For existing orders, set job_id equal to order_id if job_id is nil
    # This is a fallback to ensure all orders have a unique job_id
    execute <<-SQL
      UPDATE orders
      SET job_id = order_id
      WHERE job_id IS NULL
    SQL
  end

  def down
    # No need to revert this migration
  end
end
