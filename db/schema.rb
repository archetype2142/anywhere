# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_02_27_004922) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "auth_tokens", force: :cascade do |t|
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "commission_settings", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.decimal "minimum_order_value"
    t.decimal "maximum_order_value"
    t.decimal "commission_value"
    t.integer "commission_type"
    t.boolean "is_default"
    t.integer "delivery_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id"], name: "index_commission_settings_on_merchant_id"
  end

  create_table "merchants", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "marketplace_user_id"
    t.string "stripe_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform_user_id"
    t.integer "business_type", default: 0, null: false
    t.string "anywhere_merchant_id"
    t.index ["business_type"], name: "index_merchants_on_business_type"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_id"
    t.bigint "merchant_id", null: false
    t.decimal "amount"
    t.decimal "commission_amount"
    t.decimal "payout_amount"
    t.integer "status"
    t.string "stripe_transfer_id"
    t.string "currency_code", default: "USD"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "transaction_id"
    t.string "job_id"
    t.integer "order_type", default: 0, null: false
    t.string "parent_order_job_id"
    t.index ["job_id"], name: "index_orders_on_job_id", unique: true
    t.index ["merchant_id"], name: "index_orders_on_merchant_id"
    t.index ["order_id"], name: "index_orders_on_order_id"
    t.index ["order_type"], name: "index_orders_on_order_type"
    t.index ["transaction_id"], name: "index_orders_on_transaction_id"
  end

  create_table "pending_charges", force: :cascade do |t|
    t.string "charge_id"
    t.decimal "amount"
    t.string "currency"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_pending_charges_on_charge_id", unique: true
  end

  create_table "related_orders", force: :cascade do |t|
    t.integer "parent_order_id", null: false
    t.integer "child_order_id", null: false
    t.integer "relationship_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_order_id"], name: "index_related_orders_on_child_order_id"
    t.index ["parent_order_id", "child_order_id"], name: "index_related_orders_on_parent_order_id_and_child_order_id", unique: true
  end

  create_table "retry_attempts", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.integer "attempt_number"
    t.string "status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_retry_attempts_on_order_id"
  end

  add_foreign_key "commission_settings", "merchants"
  add_foreign_key "orders", "merchants"
  add_foreign_key "related_orders", "orders", column: "child_order_id"
  add_foreign_key "related_orders", "orders", column: "parent_order_id"
  add_foreign_key "retry_attempts", "orders"
end
