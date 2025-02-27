class RemoveUniqueConstraintFromOrderId < ActiveRecord::Migration[7.2]
  def up
    # Remove the unique index on order_id
    remove_index :orders, :order_id
    
    # Add a non-unique index back
    add_index :orders, :order_id
  end

  def down
    # Restore the unique index
    remove_index :orders, :order_id
    add_index :orders, :order_id, unique: true
  end
end
