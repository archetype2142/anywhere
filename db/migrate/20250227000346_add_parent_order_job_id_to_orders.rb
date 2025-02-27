class AddParentOrderJobIdToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :parent_order_job_id, :string
  end
end
