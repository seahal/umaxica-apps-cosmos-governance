# typed: false
# frozen_string_literal: true

require "test_helper"

# The Base withdrawal re-entry endpoint bounds address probing per source.
class BaseEndpointRateLimitTest < ActionDispatch::IntegrationTest
  rate_limit_counters!

  self.fixture_table_names = []

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  CEREMONY_REENTRY_QUOTA = 5

  test "the app withdrawal re-entry endpoint bounds address probing per source" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    CEREMONY_REENTRY_QUOTA.times do
      post base_app_identity_withdrawal_session_path(ri: "jp"), params: { address: "probe@example.com" }
    end

    assert_not_equal 429, response.status

    post base_app_identity_withdrawal_session_path(ri: "jp"), params: { address: "probe@example.com" }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end
end
