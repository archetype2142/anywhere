class AnywhereClubsApi
  include HTTParty
  base_uri 'https://admin.anywhereclubs.store/api'

  def self.login
    response = post('/user_login', body: {
      device_type: 'WEB',
      domain_name: 'https://admin.anywhereclubs.store',
      email: ENV['ANYWHERE_CLUBS_EMAIL'],
      password: ENV['ANYWHERE_CLUBS_PASSWORD'],
      timezone: -60,
      version: 1
    }.to_json, headers: { 'Content-Type' => 'application/json' })

    if response.success?
      # Parse the response body as a string first
      parsed_response = JSON.parse(response.body.to_s)
      token = parsed_response['data']['access_token']

      # Store the token
      AuthToken.create_or_find_by(token: token, expires_at: 24.hours.from_now)
      token
    else
      Rails.logger.error("Failed to login: #{response.body}")
      nil
    end
  end

  def self.get_access_token
    # Check if we have a valid token
    token_record = AuthToken.valid.first
    return token_record.token if token_record

    login
  end

  def self.get_stripe_account_details(merchant_id)
    token = get_access_token
    return nil unless token

    response = post('/merchant/getStripeAccountDetailsv2',
      body: {
      access_token: token,
        marketplace_user_id: merchant_id,
        user_id: ENV['ANYWHERE_CLUBS_USER_ID'],
        user_type: 2,
        language: 'en'
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Referer' => 'https://admin.anywhereclubs.store/en/dashboard/settings/payments',
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        'Accept' => 'application/json, text/plain, */*',
        'Origin' => 'https://admin.anywhereclubs.store',
        'Accept-Language' => 'en-US,en;q=0.9'
      }
    )

    if response.success?
      # Parse the response body as a string first
      parsed_response = JSON.parse(response.body.to_s)
      parsed_response['data']
    else
      Rails.logger.error("Failed to get Stripe account details: #{response.body}")
      nil
    end
  end

  def self.get_commission_settings(merchant_id)
    token = get_access_token
    return nil unless token

    response = get('/storefront/getCommissionSettings', query: {
      access_token: token,
      marketplace_user_id: merchant_id,
      user_type: 2,
      user_id: ENV['ANYWHERE_CLUBS_USER_ID']
    }, headers: {
      'Content-Type' => 'application/json',
      'Referer' => "https://admin.anywhereclubs.store/en/dashboard/merchants/merchant-details/#{merchant_id}",
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.142.86 Safari/537.36'
    })

    if response.success?
      # Parse the response body as a string first
      parsed_response = JSON.parse(response.body.to_s)
      parsed_response['data']['commissionValues']
    else
      Rails.logger.error("Failed to get commission settings: #{response.body}")
      nil
    end
  end

  def self.get_merchant_details(merchant_id)
    # Use the open API to fetch merchant details
    response = HTTParty.post('https://api.yelo.red/open/merchant/get', body: {
      api_key: ENV['ANYWHERE_CLUBS_API_KEY'],
      user_id: ENV['ANYWHERE_CLUBS_USER_ID'],
      marketplace_user_id: merchant_id
    }.to_json, headers: { 'Content-Type' => 'application/json' })

    if response.success?
      # Parse the response body as a string first
      parsed_response = JSON.parse(response.body.to_s)
      merchant_data = parsed_response['data']
      
      # Extract business_type if available
      if merchant_data && merchant_data['business_type'].present?
        business_type = merchant_data['business_type'].to_i
        Rails.logger.info("Merchant #{merchant_id} has business_type: #{business_type}")
        
        # Map business_type values to our enum (1 = trainer, 2 = gym)
        if business_type == 1
          merchant_data['business_type'] = :trainer
        elsif business_type == 2
          merchant_data['business_type'] = :gym
        else
          merchant_data['business_type'] = :unknown
        end
      end
      
      merchant_data
    else
      # Parse the response body as a string first
      begin
        parsed_response = JSON.parse(response.body.to_s)
        error_message = parsed_response['message'] || response.body.to_s
      rescue
        error_message = response.body.to_s
      end
      Rails.logger.error("Failed to get merchant details: #{error_message}")
      nil
    end
  end
  
  def self.get_order_details(order_id)
    response = HTTParty.post('https://api.yelo.red/open/orders/getDetails', body: {
      api_key: ENV['ANYWHERE_CLUBS_API_KEY'],
      job_id: order_id,
    })

    if response.success?
      # Parse the response body as a string first
      parsed_response = JSON.parse(response.body.to_s)
      parsed_response['data'][0]
    else
      Rails.logger.error("Failed to get order details: #{response.body}")
      nil
    end
  end
end
