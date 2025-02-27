class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.string :order_id
      t.references :merchant, null: false, foreign_key: true
      t.decimal :amount
      t.decimal :commission_amount
      t.decimal :payout_amount
      t.integer :status
      t.string :stripe_transfer_id
      t.string :currency_code, default: 'USD'

      t.timestamps
    end
    add_index :orders, :order_id, unique: true
  end
end
