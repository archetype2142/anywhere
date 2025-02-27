class RelatedOrder < ApplicationRecord
  belongs_to :parent_order, class_name: 'Order'
  belongs_to :child_order, class_name: 'Order'

  validates :parent_order_id, uniqueness: { scope: :child_order_id }
  validates :relationship_type, presence: true

  # Types of relationships between orders
  enum :relationship_type, [:gym_booking]
end
