class AddBusinessTypeToMerchants < ActiveRecord::Migration[7.2]
  def change
    add_column :merchants, :business_type, :integer, default: 0, null: false
    add_index :merchants, :business_type
  end
end
