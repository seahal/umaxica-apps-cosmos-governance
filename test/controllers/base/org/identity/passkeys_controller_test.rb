# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @passkey = @operator.staff_passkeys.active.first
    @headers = as_staff_headers(@operator, host: @host)
  end

  test "passkey details refuse without locally supported step-up evidence" do
    RuntimeRole.stub(:current, "rp-base-org-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        get base_org_identity_passkey_url(@passkey.external_id, ri: "jp", host: @host), headers: @headers
      end
    end

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_not_includes response.body, @passkey.description
  end
end
