class CreateRetryAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :retry_attempts do |t|
      t.references :order, null: false, foreign_key: true
      t.integer :attempt_number
      t.string :status
      t.text :error_message

      t.timestamps
    end
  end
end
