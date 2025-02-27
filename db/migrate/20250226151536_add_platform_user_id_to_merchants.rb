class AddPlatformUserIdToMerchants < ActiveRecord::Migration[7.2]
  def change
    add_column :merchants, :platform_user_id, :string
  end
end
