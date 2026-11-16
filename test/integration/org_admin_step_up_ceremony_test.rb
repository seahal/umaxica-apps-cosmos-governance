# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

# The owner API and RP session enforce the Support gate. The signed OIDC callback and evidence
# validation are covered by the RP callback operation tests; this file exercises the Base consumer.
class OrgAdminStepUpCeremonyTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    https!
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "Support revocation cannot infer missing Access authority from its verified RP proof" do
    host! @base_host
    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(@operator, host: @base_host)
      session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      session = RpBaseOrgSession.find_by!(public_id: session_id)
      states_before = RpBaseOrgStepUpState.count
      events_before = AppIdentityAuthenticationEvent.count
      2.times do
        get new_base_org_support_client_revocation_path(@client.public_id, ri: "jp"), headers: headers

        assert_response :service_unavailable
        assert_includes response.headers["Cache-Control"], "no-store"
        assert_equal states_before, RpBaseOrgStepUpState.count
        assert_equal events_before, AppIdentityAuthenticationEvent.count
        assert_nil session.reload.revoked_at
      end
    end
  end
end
