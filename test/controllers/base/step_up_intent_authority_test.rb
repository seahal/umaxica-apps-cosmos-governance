# frozen_string_literal: true

require "test_helper"
require_relative "../../support/rp_cell_session_helper"

# Base ordinary step-up stays RP-local, but its retired OIDC authorization endpoint makes starts
# unavailable until an owned provider exists. Refusal must leave no partial request or audit state.
class BaseStepUpIntentAuthorityTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  test "APP ordinary verification fails closed when its authorization endpoint is unavailable" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "step-up-intent-authority-passkey",
      sign_count: 0,
      description: "Step-up intent test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!

    as_rp_cell("base-app-ww") do
      headers = as_user_headers(actor, host: base_host)
      session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseAppSession.find_by!(public_id: session_id)

      get base_app_verification_path(ri: "jp"), headers: headers

      assert_response :success
      states_before = RpStepUpState.where(rp_session:).count
      outbox_before = RpStepUpAuditOutbox.count

      post base_app_verification_path(ri: "jp"),
           params: { return_target: "/settings/birthdate" },
           headers: headers.merge("Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin")

      assert_response :service_unavailable
      assert_equal states_before, RpStepUpState.where(rp_session:).count
      assert_equal outbox_before, RpStepUpAuditOutbox.count
    end
  end
end
