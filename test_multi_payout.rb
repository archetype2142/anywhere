#!/usr/bin/env ruby
# This script tests the multi-payout order system

require_relative 'config/environment'

# Create test data
puts "Creating test data..."

# Create a trainer merchant
trainer = Merchant.find_or_create_by(marketplace_user_id: "trainer123") do |m|
  m.name = "Test Trainer"
  m.email = "trainer@example.com"
  m.business_type = :trainer
  m.stripe_account_id = "acct_test_trainer"
end
puts "Created trainer: #{trainer.id} (#{trainer.name})"

# Create a gym merchant
gym = Merchant.find_or_create_by(marketplace_user_id: "gym456") do |m|
  m.name = "Test Gym"
  m.email = "gym@example.com"
  m.business_type = :gym
  m.stripe_account_id = "acct_test_gym"
end
puts "Created gym: #{gym.id} (#{gym.name})"

# Create a trainer order
trainer_order = Order.find_or_create_by(job_id: "trainer_job_123") do |o|
  o.merchant = trainer
  o.order_id = "trainer_order_123"
  o.amount = 100.0
  o.commission_amount = 20.0
  o.payout_amount = 80.0
  o.status = :paid
  o.currency_code = "USD"
  o.order_type = :regular
end
puts "Created trainer order: #{trainer_order.id} (#{trainer_order.job_id})"

# Create a gym booking order
gym_order = Order.find_or_create_by(job_id: "gym_job_456") do |o|
  o.merchant = gym
  o.order_id = "gym_order_456"
  o.amount = 20.0
  o.commission_amount = 2.0
  o.payout_amount = 18.0
  o.status = :paid
  o.currency_code = "USD"
  o.order_type = :gym_booking
  o.parent_order_job_id = trainer_order.job_id
end
puts "Created gym order: #{gym_order.id} (#{gym_order.job_id})"

# Create relationship between orders
relationship = RelatedOrder.find_or_create_by(
  parent_order: trainer_order,
  child_order: gym_order
) do |r|
  r.relationship_type = :gym_booking
end
puts "Created relationship: #{relationship.id} (#{relationship.relationship_type})"

# Test querying related orders
puts "\nTesting related orders queries..."
puts "Trainer order child orders: #{trainer_order.child_orders.map(&:job_id).join(', ')}"
puts "Gym order parent orders: #{gym_order.parent_orders.map(&:job_id).join(', ')}"

# Test finding orders by type
puts "\nTesting order type queries..."
puts "Regular orders: #{Order.where(order_type: :regular).count}"
puts "Gym booking orders: #{Order.where(order_type: :gym_booking).count}"

# Test finding merchants by business type
puts "\nTesting business type queries..."
puts "Trainers: #{Merchant.where(business_type: :trainer).count}"
puts "Gyms: #{Merchant.where(business_type: :gym).count}"

puts "\nTest completed successfully!"
