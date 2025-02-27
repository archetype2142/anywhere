class CreateCommissionSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :commission_settings do |t|
      t.references :merchant, null: false, foreign_key: true
      t.decimal :minimum_order_value
      t.decimal :maximum_order_value
      t.decimal :commission_value
      t.integer :commission_type
      t.boolean :is_default
      t.integer :delivery_type

      t.timestamps
    end
  end
end
