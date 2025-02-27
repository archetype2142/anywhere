class AddJobIdToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :job_id, :string
    add_index :orders, :job_id, unique: true
  end
end
