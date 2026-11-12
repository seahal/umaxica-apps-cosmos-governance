# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class BaseStepUpStartTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  test "Base APP GET is read-only and POST refuses after Auth retirement without creating state" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "base-app-step-up-public-key",
      sign_count: 0,
      description: "Step-up test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!

    as_rp_cell("base-app-ww") do
      headers = as_user_headers(actor, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
      local_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseAppSession.find_by!(public_id: local_id)
      initial_states = RpStepUpState.where(rp_session:).count
      initial_outboxes = RpStepUpAuditOutbox.count

      get base_app_verification_path(ri: "jp"), headers: headers

      assert_response :success
      assert_includes response.headers.fetch("Cache-Control"), "private"
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_includes response.body, '"return_target":"/identity"'
      assert_equal initial_states, RpStepUpState.where(rp_session:).count
      assert_equal initial_outboxes, RpStepUpAuditOutbox.count

      ["https://attacker.example/", "//attacker.example", "/sign/out", "", ["/identity"]].each do |target|
        post base_app_verification_path(ri: "jp"), params: { return_target: target }, headers: headers

        assert_response :bad_request, target.inspect
        assert_equal initial_states, RpStepUpState.where(rp_session:).count
        assert_equal initial_outboxes, RpStepUpAuditOutbox.count
      end

      post base_app_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers.fetch("Cache-Control"), "private"
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal initial_states, RpStepUpState.where(rp_session:).count
      assert_equal initial_outboxes, RpStepUpAuditOutbox.count
      assert_nil rp_session.reload.revoked_at
    end
  end

  test "Base ORG refuses Auth-mediated step-up without creating state" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskey.create!(
      staff: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "base-org-step-up-public-key",
      sign_count: 0,
      description: "Step-up test passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    https!

    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"))
      local_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseOrgSession.find_by!(public_id: local_id)

      post base_org_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }, headers: headers

      assert_response :service_unavailable
      assert_empty RpBaseOrgStepUpState.where(rp_session:)
      assert_empty RpBaseOrgStepUpAuditOutbox.all
      assert_nil rp_session.reload.revoked_at
    end
  end

  test "Base ORG standby context refuses step-up before creating RP state" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    https!

    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"))
      local_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseOrgSession.find_by!(public_id: local_id)
      token = jwt_access_token_for(
        actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), resource_type: "operator",
               authentication_context: AuthenticationContextValue::STANDBY_KEY,
      )
      browser_cookies = Rack::Utils.parse_cookies_header(headers.fetch("Cookie"))
      browser_cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token
      cookie_header = browser_cookies.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; ")
      headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
      states_before = RpBaseOrgStepUpState.where(rp_session:).count
      outboxes_before = RpBaseOrgStepUpAuditOutbox.count

      post base_org_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }, headers: headers

      assert_response :forbidden
      assert_equal states_before, RpBaseOrgStepUpState.where(rp_session:).count
      assert_equal outboxes_before, RpBaseOrgStepUpAuditOutbox.count
    end
  end
end
