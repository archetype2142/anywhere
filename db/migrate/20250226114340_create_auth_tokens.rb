class CreateAuthTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :auth_tokens do |t|
      t.string :token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
