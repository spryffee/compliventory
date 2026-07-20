require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  # Rack::Attack is disabled in test by default (so the rest of the suite isn't
  # throttled). These tests flip it on with a real per-process cache store, since
  # the default test cache is :null_store and would never accumulate counts.
  def setup
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  def teardown
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @original_store
  end

  test "trips the auth per-IP throttle and returns the rate_limited envelope" do
    # Limit is 5 per 20s; the 6th request from the same IP is throttled.
    5.times do
      post "/auth/oidc"
      assert_not_equal 429, response.status
    end

    post "/auth/oidc"

    assert_response :too_many_requests
    assert_equal "rate_limited", JSON.parse(response.body).dig("error", "code")
    assert response.headers["Retry-After"].to_i.positive?
    assert JSON.parse(response.body).dig("error", "details", "retry_after").positive?
  end

  test "lets requests under the limit through" do
    3.times do
      post "/auth/oidc"
      assert_not_equal 429, response.status
    end
  end
end
