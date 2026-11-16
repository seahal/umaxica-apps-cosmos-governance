# frozen_string_literal: true

require "test_helper"

class TechOrgAccessRevocationTest < ActionDispatch::IntegrationTest
  test "valid Tech RP proof cannot replace unavailable Access authority and keeps local credentials" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    client = OidcClientRegistry.find!("tech-org-ww")
    session = seed_rp_browser_session(
      client:, actor: operator, sid: SecureRandom.uuid, absolute_expires_at: 1.hour.from_now,
    )
    now = Time.current.to_i
    claims = {
      "iss" => OidcIssuer.for_client(client),
      "sub" => OidcSubject.for(operator, resource_type: "operator"),
      "aud" => [client.aud],
      "client_id" => client.client_id,
      "sid" => session.op_session_binding.sid,
      "jti" => SecureRandom.uuid,
      "scope" => "openid profile domain:operator",
      "iat" => now,
      "nbf" => now,
      "exp" => now + 600,
      "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
    }
    token = JitSecurityJwtKeyring.encode(
      claims, typ: "at+jwt", issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )
    host! ENV.fetch("PUBLIC_TECH_STAFF_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = session.public_id
    as_rp_cell("tech-org-ww") do
      install_base_rp_jwks_client(client_id: client.client_id, access_token: token)
      2.times do
        get tech_org_dashboard_path(ri: "jp")

        assert_response :service_unavailable
        assert_includes response.headers["Cache-Control"], "no-store"
        assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
        assert_equal token, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_equal session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
        assert_nil session.reload.revoked_at
      end
    end
  end

  test "invalid Tech credential is refused before any authority query" do
    host! ENV.fetch("PUBLIC_TECH_STAFF_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "invalid-external-proof"

    as_rp_cell("tech-org-ww") do
      get tech_org_dashboard_path(ri: "jp")
    end

    assert_response :unauthorized
    assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
  end
end
