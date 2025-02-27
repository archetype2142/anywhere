class Merchant < ApplicationRecord
  has_many :commission_settings, dependent: :destroy
  has_many :orders, dependent: :nullify

  validates :marketplace_user_id, presence: true

  # Add business_type enum to distinguish between trainers and gyms
  enum :business_type, [:unknown, :trainer, :gym], default: :unknown

  # Create or update a merchant from webhook data
  def self.create_from_webhook(merchant_data)
    marketplace_user_id = merchant_data['marketplace_user_id']
    name = "#{merchant_data['first_name']} #{merchant_data['last_name']}"
    email = merchant_data['merchant_email']
    business_type = merchant_data['business_type'].to_i if merchant_data['business_type']

    merchant = Merchant.find_or_initialize_by(marketplace_user_id: marketplace_user_id.to_s)
    merchant.assign_attributes(
      name: name,
      email: email,
      platform_user_id: merchant_data['user_id'],
      business_type: business_type || :unknown
    )

    if merchant.save
      # Fetch Stripe account ID and commission settings
      merchant.fetch_and_update_stripe_account
      merchant.fetch_and_update_commission_settings
      Rails.logger.info("Merchant saved with business_type: #{merchant.business_type}")
      merchant
    else
      Rails.logger.error("Failed to save merchant: #{merchant.errors.full_messages.join(', ')}")
      nil
    end
  end

  def fetch_and_update_commission_settings
    commission_data = AnywhereClubsApi.get_commission_settings(marketplace_user_id)
    return unless commission_data

    # Clear existing commission settings
    commission_settings.destroy_all

    # Create new commission settings
    commission_data.each do |setting|
      commission_settings.create!(
        minimum_order_value: setting['minimum_order_value'],
        maximum_order_value: setting['maximum_order_value'],
        commission_value: setting['commission_value'],
        commission_type: setting['commission_type'], # 0 = fixed, 1 = percentage
        is_default: setting['is_default'] == 1,
        delivery_type: setting['delivery_type']
      )
    end
  end

  def fetch_and_update_stripe_account
    begin
      stripe_data = AnywhereClubsApi.get_stripe_account_details(marketplace_user_id)&.fetch('account_details', '')
      
      if stripe_data && stripe_data['stripe_account_id'].present?
        update(stripe_account_id: stripe_data['stripe_account_id'])
        return true
      else
        Rails.logger.error("No Stripe account found for merchant #{marketplace_user_id}")
        return false
      end
    rescue => e
      Rails.logger.error("Error fetching Stripe account for merchant #{marketplace_user_id}: #{e.message}")
      return false
    end
  end
end
