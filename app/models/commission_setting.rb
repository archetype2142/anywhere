class CommissionSetting < ApplicationRecord
  belongs_to :merchant

  enum commission_type: { fixed: 0, percentage: 1 }
  enum delivery_type: { all_types: 0, pickup: 1, delivery: 2, shipping: 3, online: 4 }

  validates :commission_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :minimum_order_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :maximum_order_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :default, -> { where(is_default: true) }
  scope :for_order_amount, ->(amount) { 
    where('(minimum_order_value <= ? AND maximum_order_value >= ?) OR (is_default = ? AND minimum_order_value = ? AND maximum_order_value = ?)', 
          amount, amount, true, 0, 0) 
  }
end
