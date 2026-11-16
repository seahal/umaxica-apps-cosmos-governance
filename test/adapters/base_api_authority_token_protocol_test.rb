# frozen_string_literal: true

require "test_helper"

class BaseApiAuthorityTokenProtocolTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  APP_CELL = RpCellBinding.fetch("rp_base_app")
  ISSUER_ID = "surface:BASE_APP"
  TOKEN_TYPE = "umaxica-base-api+jwt"

  setup do
    @now = Time.current.change(usec: 0)
    digest = Digest::SHA256.hexdigest("base-api-id-token-jti")
    @callback = RpCallbackCommitter.call(
      cell: APP_CELL,
      issuer: "https://visa.umaxica.app",
      subject: "base-api-subject",
      sid: "base-api-sid",
      absolute_expires_at: @now + 1.hour,
      id_token_jti_digest: digest,
      id_token_expires_at: @now + 2.minutes,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => @now.to_i,
        "id_token_jti_digest" => digest,
      },
    )

    assert_predicate @callback, :success?
  end

  test "the issuer signs the exact minimal Base App profile for its active sid-bound session" do
    token = BaseApiAuthorityTokenIssuer.issue(rp_session: @callback.session)
    payload, header = JWT.decode(token, nil, false)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    assert_equal(
      { "alg" => "PS256",
        "kid" => JitSecurityJwtRegistry.surface("BASE_APP").current_kid,
        "typ" => TOKEN_TYPE, }, header,
    )
    assert_equal %w(act aud client_id exp iat iss jti realm rp_session_id sub), payload.keys.sort
    assert_equal JitSecurityJwtRegistry.surface("BASE_APP").issuer, payload.fetch("iss")
    assert_equal hosts.base_service.to_s, payload.fetch("aud")
    assert_equal APP_CELL.client_id, payload.fetch("client_id")
    assert_equal APP_CELL.realm, payload.fetch("realm")
    assert_equal payload.fetch("sub"), payload.fetch("act")
    assert_equal @callback.session.public_id, payload.fetch("rp_session_id")
    assert_equal 300, payload.fetch("exp") - payload.fetch("iat")
    assert_predicate BaseApiAuthorityTokenVerifier.call(
      token:, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?
  end

  test "the verifier refuses a wrong type, realm, audience, extra claim, expiry and lifetime above five minutes" do
    session = @callback.session
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    issuer = JitSecurityJwtRegistry.surface("BASE_APP").issuer
    now = @now.to_i
    base_claims = {
      "iss" => issuer,
      "aud" => hosts.base_service.to_s,
      "sub" => "base-api-subject",
      "act" => "base-api-subject",
      "rp_session_id" => session.public_id,
      "client_id" => APP_CELL.client_id,
      "realm" => APP_CELL.realm,
      "jti" => JitSecurityJwtJtiGenerator.generate,
      "iat" => now,
      "exp" => now + 300,
    }

    valid = JitSecurityJwtKeyring.encode(base_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_predicate BaseApiAuthorityTokenVerifier.call(
      token: valid, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    below_limit_claims = base_claims.merge("exp" => now + 299)
    below_limit = JitSecurityJwtKeyring.encode(below_limit_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_predicate BaseApiAuthorityTokenVerifier.call(
      token: below_limit, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    wrong_type = JitSecurityJwtKeyring.encode(base_claims, typ: "JWT", issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: wrong_type, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    handoff_state, = OidcStateJwt.issue(client_id: APP_CELL.client_id, target_link_uri: nil)
    preference_token = JitSecurityJwtKeyring.encode(
      base_claims, typ: SecurityJwtPreferenceTokenCodec::TOKEN_TYPE, issuer_id: ISSUER_ID,
    )

    [handoff_state, preference_token].each do |other_type_token|
      assert_not_predicate BaseApiAuthorityTokenVerifier.call(
        token: other_type_token, expected_client_id: APP_CELL.client_id,
        expected_audience_resource_type: "client",
      ), :authenticated?
    end

    wrong_realm_claims = base_claims.merge("realm" => "org")
    wrong_realm = JitSecurityJwtKeyring.encode(wrong_realm_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: wrong_realm, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    wrong_audience_claims = base_claims.merge("aud" => hosts.base_staff.to_s)
    wrong_audience = JitSecurityJwtKeyring.encode(wrong_audience_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: wrong_audience, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    extra_claims = base_claims.merge("email" => "not-permitted@example.test")
    extra = JitSecurityJwtKeyring.encode(extra_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: extra, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    expired_claims = base_claims.merge("exp" => now)
    expired = JitSecurityJwtKeyring.encode(expired_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: expired, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?

    too_long_claims = base_claims.merge("exp" => now + 301)
    too_long = JitSecurityJwtKeyring.encode(too_long_claims, typ: TOKEN_TYPE, issuer_id: ISSUER_ID)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: too_long, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?
  end

  test "a correctly signed API token is refused after back-channel revocation ends its RP session" do
    token = BaseApiAuthorityTokenIssuer.issue(rp_session: @callback.session)

    RpBaseAppOpSessionBinding.find(@callback.session.op_session_binding_id).update!(revoked_at: @now)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token:, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?
  end

  test "the issuer refuses a session revoked before issuance" do
    @callback.session.update!(revoked_at: @now)

    assert_raises(BaseApiAuthorityTokenIssuer::InactiveRpSession) do
      BaseApiAuthorityTokenIssuer.issue(rp_session: @callback.session)
    end
  end

  test "a Base Org authority token cannot authenticate to the Base App receiver" do
    cell = RpCellBinding.fetch("rp_base_org")
    digest = Digest::SHA256.hexdigest("other-realm-api-id-token-jti")
    callback = RpCallbackCommitter.call(
      cell:, issuer: "https://visa.umaxica.org", subject: "base-org-api-subject", sid: "base-org-api-sid",
      absolute_expires_at: @now + 1.hour, id_token_jti_digest: digest,
      id_token_expires_at: @now + 2.minutes,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => @now.to_i,
        "id_token_jti_digest" => digest,
      },
    )
    token = BaseApiAuthorityTokenIssuer.issue(rp_session: callback.session)

    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token:, expected_client_id: APP_CELL.client_id, expected_audience_resource_type: "client",
    ), :authenticated?
  end
end
