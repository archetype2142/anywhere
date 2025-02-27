class CreatePendingCharges < ActiveRecord::Migration[7.2]
  def change
    create_table :pending_charges do |t|
      t.string :charge_id
      t.decimal :amount
      t.string :currency
      t.text :metadata

      t.timestamps
    end
    
    add_index :pending_charges, :charge_id, unique: true
  end
end
