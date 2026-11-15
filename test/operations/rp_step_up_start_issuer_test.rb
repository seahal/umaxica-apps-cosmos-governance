# frozen_string_literal: true

require "test_helper"

class RpStepUpStartIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a local RP principal disabled after token authentication refuses stale step-up admission" do
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    cell = RpCellBinding.for_client("base-org-ww")
    client = OidcClientRegistry.find!(cell.client_id)
    issuer = rp_test_issuer_for(client)
    subject = OidcSubject.for(operator, resource_type: "operator")
    sid = SecureRandom.uuid
    local_principal = RpBaseOrgPrincipal.create!
    identity_binding = RpBaseOrgIdentityBinding.create!(
      principal: local_principal,
      issuer: issuer,
      realm: cell.realm,
      client_id: cell.client_id,
      subject: subject,
    )
    op_session_binding = RpBaseOrgOpSessionBinding.create!(
      identity_binding: identity_binding,
      issuer: issuer,
      realm: cell.realm,
      client_id: cell.client_id,
      sid: sid,
    )
    rp_session = RpBaseOrgSession.create!(
      op_session_binding: op_session_binding,
      absolute_expires_at: 1.hour.from_now,
      installed_generation: 0,
    )
    key = OpenSSL::PKey::RSA.generate(3072)
    kid = "rp-step-up-disabled-principal"
    now = Time.current.to_i
    access_token = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => cell.client_id,
        AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
      },
      key,
      "PS256",
      { "kid" => kid, "typ" => "at+jwt" },
    )
    jwks_client = OidcOpJwksClient.new(
      jwks_uri: rp_test_jwks_uri_for(client),
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: kid)] } },
    )
    authentication = RpRequestAuthenticator.call(
      cell: cell,
      access_token: access_token,
      local_session_id: rp_session.public_id,
      issuer: issuer,
      jwks_client: jwks_client,
    )

    assert_equal :authenticated, authentication.status
    assert_equal local_principal.id, authentication.principal.id
    assert_equal rp_session.id, authentication.session.id

    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: authentication.principal,
      rp_session: authentication.session,
      payload: authentication.payload,
      security_context: nil,
    )
    RpBaseOrgPrincipal.find(local_principal.id).update!(disabled_at: Time.current)
    states_before = RpBaseOrgStepUpState.count
    outboxes_before = RpBaseOrgStepUpAuditOutbox.count

    refusal =
      assert_raises(RpStepUpStartIssuer::Refused) do
        RpStepUpStartIssuer.call(
          cell: cell,
          access_state: access_state,
          actor: operator,
          browser_binding: SecureRandom.urlsafe_base64(32),
          return_target: "/identity",
        )
      end

    assert_equal "rp_binding_changed", refusal.reason_code
    assert_equal states_before, RpBaseOrgStepUpState.count
    assert_equal outboxes_before, RpBaseOrgStepUpAuditOutbox.count
    assert_nil rp_session.reload.revoked_at
    assert_predicate RpBaseOrgPrincipal.find(local_principal.id).disabled_at, :present?
  end
end
