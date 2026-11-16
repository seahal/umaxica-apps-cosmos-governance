# frozen_string_literal: true

require "test_helper"

class AppWithdrawalStepUpEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  test "a local RP login alone cannot authorize destructive withdrawal" do
    actor = clients(:one)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(actor, host:)
    original = actor.attributes

    assert_no_difference "AppIdentityAuthenticationEvent.count" do
      patch base_app_identity_withdrawal_url(ri: "jp", host:),
            params: { ack_deactivate_today: "1" }, headers: headers
    end

    assert_response :unauthorized
    assert_nil response.location
    assert_equal original, actor.reload.attributes
  end

  test "an external Access credential without its local session cannot perform withdrawal" do
    actor = clients(:one)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(actor, host:)
    headers["Cookie"] = headers.fetch("Cookie").split("; ").reject do |pair|
      pair.start_with?("#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=")
    end.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    original = actor.attributes

    patch base_app_identity_withdrawal_url(ri: "jp", host:), params: { ack_deactivate_today: "1" }, headers: headers

    assert_response :unauthorized
    assert_nil response.location
    assert_equal original, actor.reload.attributes
  end
end
