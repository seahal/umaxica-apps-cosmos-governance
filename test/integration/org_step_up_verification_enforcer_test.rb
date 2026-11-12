# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class OrgStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  test "an RP-local Org session without an OP step-up event is challenged before withdrawal" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(operator)
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! base_host
    https!

    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(operator, host: base_host)
      local_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseOrgSession.find_by!(public_id: local_id)

      get base_org_identity_withdrawal_path(ri: "jp"), headers: headers

      assert_response :redirect
      challenge = URI.parse(response.location)

      assert_equal "/verification", challenge.path
      assert_equal "operator_lifecycle", Rack::Utils.parse_nested_query(challenge.query).fetch("scope")
      assert_equal 0, RpBaseOrgStepUpState.where(rp_session:).count
      assert_nil rp_session.reload.revoked_at
    end
  end
end
