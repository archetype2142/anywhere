class CreateMerchants < ActiveRecord::Migration[7.2]
  def change
    create_table :merchants do |t|
      t.string :name
      t.string :email
      t.string :marketplace_user_id
      t.string :stripe_account_id

      t.timestamps
    end
  end
end
