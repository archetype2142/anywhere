class AddAnywhereMerchantIdToMerchants < ActiveRecord::Migration[7.2]
  def change
    add_column :merchants, :anywhere_merchant_id, :string
  end
end
