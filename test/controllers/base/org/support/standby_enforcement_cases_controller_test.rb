# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::StandbyEnforcementCasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @other = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    2.times do
      OperatorPasskey.create!(
        staff: @operator, webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid, public_key: "test-public-key",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
  end

  test "a signed Standby context cannot mutate enforcement or grants without Access authority" do
    headers = as_staff_headers(@operator, host: @host)
    payload, = JWT.decode(headers.fetch("Authorization").delete_prefix("Bearer "), nil, false)
    payload[AuthenticationContextValue::CLAIM] = AuthenticationContextValue::STANDBY_KEY
    access = JitSecurityJwtKeyring.encode(payload, typ: "at+jwt", issuer_id: "surface:BASE_ORG")
    install_base_rp_jwks_client(client_id: "base-org-ww", access_token: access)
    cookie = headers.fetch("Cookie").split("; ").map do |pair|
      name = pair.split("=", 2).first
      (name == OidcRpBrowserCredentialContract::ACCESS_COOKIE) ? "#{name}=#{Rack::Utils.escape(access)}" : pair
    end.join("; ")
    headers = headers.merge("Authorization" => "Bearer #{access}", "Cookie" => cookie, "HTTP_COOKIE" => cookie)
    before_cases = AppEnforcementCase.count
    before_grants = OperatorCapabilityGrant.count
    before_actor = @operator.reload.attributes
    [base_org_support_app_enforcement_cases_url(host: @host), base_org_iam_grants_url(host: @host)].each do |url|
      post url, params: { principal_public_id: @client.public_id,
                          operator_public_id: @other.public_id,
                          capability: OperatorCapabilityGrant::TECH_ACCESS,
                          operation_id: SecureRandom.uuid, },
                headers: headers, as: :json

      assert_response :service_unavailable
      assert_equal before_cases, AppEnforcementCase.count
      assert_equal before_grants, OperatorCapabilityGrant.count
      assert_equal before_actor, @operator.reload.attributes
    end
    assert_not AuthenticationContextValue.for(AuthenticationContextValue::STANDBY_KEY).step_up_permitted?
    assert_raises(AuthenticationContextValue::UnknownContextError) do
      AuthenticationContextValue.for("unknown-context")
    end
  end
end
