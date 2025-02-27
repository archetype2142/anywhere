class AddTransactionIdToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :transaction_id, :string
    add_index :orders, :transaction_id
  end
end
