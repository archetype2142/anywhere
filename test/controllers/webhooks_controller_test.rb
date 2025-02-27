require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "should get stripe" do
    get webhooks_stripe_url
    assert_response :success
  end

  test "should get anywhere_clubs" do
    get webhooks_anywhere_clubs_url
    assert_response :success
  end
end
