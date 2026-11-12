# frozen_string_literal: true

require "test_helper"

class WelcomeAndActivitySeamsTest < ActionDispatch::IntegrationTest
  test "ORG Welcome consistently offers its own next step without rewriting the local RP session" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "welcome-fixture-#{index}", external_id: SecureRandom.uuid,
        public_key: "welcome-fixture-key-#{index}", description: "Welcome fixture",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    headers = as_staff_headers(operator, host: host)
    session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    rp_session = RpBaseOrgSession.includes(:op_session_binding).find_by!(public_id: session_id)
    original = rp_session.reload.attributes
    count = RpBaseOrgSession.count

    2.times do
      get base_org_welcome_url(ri: "jp", host: host), headers: headers

      assert_response :success
      assert_equal "/dashboard?ri=jp", inertia_props.fetch("next_link").fetch("href")
      assert_equal count, RpBaseOrgSession.count
      assert_equal original, rp_session.reload.attributes
      assert_predicate RpBaseOrgSession.includes(:op_session_binding).find(rp_session.id), :active?
    end
  end
end
