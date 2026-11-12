# typed: false
# frozen_string_literal: true

require "test_helper"

# Preference tokens are scoped to their owning Base realm. An app preference must not affect the org
# cookie endpoint, and an org preference must not affect the app endpoint.
class CrossSurfaceTokenTest < ActionDispatch::IntegrationTest
  test "app preference token is ignored by the org cookie endpoint" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    token = nil

    with_preference_realm_issuers do
      token = PreferenceToken.encode(
        { "consented" => true },
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        preference_type: "AppPreference",
        public_id: "app-pref-public-id",
        jti: "test-jti-#{SecureRandom.uuid}",
        issued_at: Time.current,
      )
    end
    cookies[PreferenceCookieName.anonymous_jwt] = token

    with_preference_realm_issuers do
      get "/api/v0/preferences/cookie", headers: { "Host" => host, "Accept" => "application/json" }, as: :json
    end

    assert_response :ok
    assert response.parsed_body["show_banner"], "app preference token must not suppress the org banner"
  end

  test "org preference token is ignored by the app cookie endpoint" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = nil

    with_preference_realm_issuers do
      token = PreferenceToken.encode(
        { "consented" => true },
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        preference_type: "OrgPreference",
        public_id: "org-pref-public-id",
        jti: "test-jti-#{SecureRandom.uuid}",
        issued_at: Time.current,
      )
    end
    cookies[PreferenceCookieName.anonymous_jwt] = token

    with_preference_realm_issuers do
      get "/api/v0/preferences/cookie", headers: { "Host" => host, "Accept" => "application/json" }, as: :json
    end

    assert_response :ok
    assert response.parsed_body["show_banner"], "org preference token must not suppress the app banner"
  end
end
