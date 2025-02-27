class CreateRelatedOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :related_orders do |t|
      t.integer :parent_order_id, null: false
      t.integer :child_order_id, null: false
      t.integer :relationship_type, null: false, default: 0

      t.timestamps
    end

    add_index :related_orders, [:parent_order_id, :child_order_id], unique: true
    add_index :related_orders, :child_order_id
    
    add_foreign_key :related_orders, :orders, column: :parent_order_id
    add_foreign_key :related_orders, :orders, column: :child_order_id
  end
end
