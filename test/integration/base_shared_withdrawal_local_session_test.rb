# frozen_string_literal: true

require "test_helper"
class BaseSharedWithdrawalLocalSessionTest < ActionDispatch::IntegrationTest
  test "deactivated APP local RP session redirects and cannot open withdrawal pages" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "shared-app-public-key", sign_count: 0, description: "Test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    headers = as_user_headers(actor, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    browser_cookies = Rack::Utils.parse_cookies_header(headers.fetch("Cookie"))
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = browser_cookies.fetch(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
    )
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = browser_cookies.fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    rp_session = RpBaseAppSession.find_by!(
      public_id: browser_cookies.fetch(OidcRpBrowserCredentialContract::SESSION_COOKIE),
    )

    actor.reload.update!(
      withdrawal_started_at: 2.hours.ago, deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now, purge_eligible_at: 31.days.from_now,
    )
    RuntimeRole.stub(:current, "shared") do
      get(base_app_identity_path(ri: "jp"))

      assert_redirected_to new_base_app_identity_withdrawal_session_path(ri: "jp")
      get(base_app_identity_path(ri: "jp"), headers: { "Accept" => "application/json" })

      assert_response :forbidden
      assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body.fetch("error")

      get(new_base_app_identity_withdrawal_path(ri: "jp"))

      assert_response :unauthorized
      assert_equal rp_session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  ensure
    if defined?(rp_session) && rp_session&.persisted?
      RpBaseAppRecord.connected_to(role: :writing) do
        binding = RpBaseAppOpSessionBinding.find(rp_session.op_session_binding_id)
        identity = RpBaseAppIdentityBinding.find(binding.identity_binding_id)
        principal_id = identity.principal_id
        RpBaseAppSession.where(id: rp_session.id).delete_all
        RpBaseAppOpSessionBinding.where(id: binding.id).delete_all
        RpBaseAppIdentityBinding.where(id: identity.id).delete_all
        RpBaseAppPrincipal.where(id: principal_id).delete_all

        assert_not RpBaseAppSession.exists?(id: rp_session.id)
        assert_not RpBaseAppOpSessionBinding.exists?(id: binding.id)
        assert_not RpBaseAppIdentityBinding.exists?(id: identity.id)
        assert_not RpBaseAppPrincipal.exists?(id: principal_id)
      end
    end
  end
end
