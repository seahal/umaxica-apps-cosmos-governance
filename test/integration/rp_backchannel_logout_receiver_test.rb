# frozen_string_literal: true

require "test_helper"

class RpBackchannelLogoutReceiverTest < ActionDispatch::IntegrationTest
  include OutboundHttpStub

  test "a Visa Logout Token tombstones its sid and revokes matching local sessions before 200" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    cell = RpCellBinding.fetch("rp_base_app")
    kid = "base-app-logout-#{SecureRandom.hex(8)}"
    sid = SecureRandom.uuid
    issuer = visa_origin.origin
    rp_session = seed_rp_cell_session(
      cell:, issuer:, subject: "base-app-logout-subject", sid:, absolute_expires_at: 1.hour.from_now,
    )
    api_token = BaseApiAuthorityTokenIssuer.issue(rp_session: rp_session, audience_resource_type: "client")
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => SecureRandom.uuid,
      "sid" => sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    logout_token = JWT.encode(
      claims, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid, "typ" => "logout+jwt" },
    )
    public_jwk = JitSecurityJwtJwk.export_public(signing_key, kid:)
    jwks_uri = visa_origin.jwks_uri
    limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current })
    jwks_client = OidcOpJwksClient.new(jwks_uri:, limiter:)
    previous_jwks_client = OidcOpJwksClient::CLIENTS[jwks_uri]
    OidcOpJwksClient::CLIENTS[jwks_uri] = jwks_client
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(jwks_uri) { [200, { "Content-Type" => "application/json" }, JSON.generate("keys" => [public_jwk])] }
      end

    stub_outbound_http(stubs) do
      post("/oidc/closures", params: { logout_token: }, headers: { "HTTP_COOKIE" => nil, "HTTP_USER_AGENT" => nil })
    end
    stubs.verify_stubbed_calls

    assert_nil request.get_header("HTTP_USER_AGENT")
    assert_empty request.cookies
    assert_response :ok
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate rp_session.reload.revoked_at, :present?
    binding = RpBaseAppOpSessionBinding.find_by!(issuer:, sid:)

    assert_predicate binding.revoked_at, :present?
    assert_not_predicate BaseApiAuthorityTokenVerifier.call(
      token: api_token, expected_client_id: cell.client_id, expected_audience_resource_type: "client",
    ), :authenticated?
    assert_equal 1, RpBaseAppEventReceipt.where(client_id: cell.client_id).count

    post("/oidc/closures", params: { logout_token: }, headers: { "HTTP_COOKIE" => nil, "HTTP_USER_AGENT" => nil })

    assert_response :ok
    assert_equal 1, RpBaseAppEventReceipt.where(client_id: cell.client_id).count
  ensure
    if defined?(jwks_uri) && jwks_uri.present?
      previous_jwks_client ? OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client :
        OidcOpJwksClient::CLIENTS.delete(jwks_uri)
    end
  end

  test "a valid logout for an unknown sid commits a tombstone before acknowledging" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    cell = RpCellBinding.fetch("rp_base_app")
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-unknown-sid-#{SecureRandom.hex(8)}"
    sid = SecureRandom.uuid
    now = Time.current.to_i
    claims = {
      "iss" => visa_origin.origin,
      "aud" => [cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => SecureRandom.uuid,
      "sid" => sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    logout_token = JWT.encode(
      claims, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid, "typ" => "logout+jwt" },
    )
    public_jwk = JitSecurityJwtJwk.export_public(signing_key, kid:)
    jwks_uri = visa_origin.jwks_uri
    previous_jwks_client = OidcOpJwksClient::CLIENTS[jwks_uri]
    OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
      jwks_uri:, limiter: OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current }),
    )
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(jwks_uri) { [200, { "Content-Type" => "application/json" }, JSON.generate("keys" => [public_jwk])] }
      end

    stub_outbound_http(stubs) { post("/oidc/closures", params: { logout_token: }) }
    stubs.verify_stubbed_calls

    assert_response :ok
    tombstone = RpBaseAppOpSessionBinding.find_by!(issuer: visa_origin.origin, sid:)

    assert_predicate tombstone.revoked_at, :present?
    assert_nil tombstone.identity_binding_id
    assert_equal 1, RpBaseAppEventReceipt.where(client_id: cell.client_id).count
  ensure
    if defined?(jwks_uri) && jwks_uri.present?
      previous_jwks_client ? OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client :
        OidcOpJwksClient::CLIENTS.delete(jwks_uri)
    end
  end

  test "a bad Logout Token signature is refused without local state changes" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    cell = RpCellBinding.fetch("rp_base_app")
    rp_session = seed_rp_cell_session(
      cell:, issuer: visa_origin.origin, subject: "signature-check-subject", sid: SecureRandom.uuid,
      absolute_expires_at: 1.hour.from_now,
    )
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    other_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-bad-signature-#{SecureRandom.hex(8)}"
    now = Time.current.to_i
    claims = {
      "iss" => visa_origin.origin,
      "aud" => [cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => SecureRandom.uuid,
      "sid" => rp_session.op_session_binding.sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    logout_token = JWT.encode(
      claims, other_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid, "typ" => "logout+jwt" },
    )
    public_jwk = JitSecurityJwtJwk.export_public(signing_key, kid:)
    jwks_uri = visa_origin.jwks_uri
    previous_jwks_client = OidcOpJwksClient::CLIENTS[jwks_uri]
    OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
      jwks_uri:, limiter: OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current }),
    )
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(jwks_uri) { [200, { "Content-Type" => "application/json" }, JSON.generate("keys" => [public_jwk])] }
      end
    before_count = RpBaseAppEventReceipt.count

    stub_outbound_http(stubs) { post("/oidc/closures", params: { logout_token: }) }
    stubs.verify_stubbed_calls

    assert_response :bad_request
    assert_nil rp_session.reload.revoked_at
    assert_equal before_count, RpBaseAppEventReceipt.count
  ensure
    if defined?(jwks_uri) && jwks_uri.present?
      previous_jwks_client ? OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client :
        OidcOpJwksClient::CLIENTS.delete(jwks_uri)
    end
  end

  test "an unavailable Visa JWKS answers 503 and makes no local change" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    cell = RpCellBinding.fetch("rp_base_app")
    rp_session = seed_rp_cell_session(
      cell:, issuer: visa_origin.origin, subject: "jwks-outage-subject", sid: SecureRandom.uuid,
      absolute_expires_at: 1.hour.from_now,
    )
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-jwks-outage-#{SecureRandom.hex(8)}"
    now = Time.current.to_i
    claims = {
      "iss" => visa_origin.origin,
      "aud" => [cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => SecureRandom.uuid,
      "sid" => rp_session.op_session_binding.sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    logout_token = JWT.encode(
      claims, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid, "typ" => "logout+jwt" },
    )
    jwks_uri = visa_origin.jwks_uri
    previous_jwks_client = OidcOpJwksClient::CLIENTS[jwks_uri]
    OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
      jwks_uri:, limiter: OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current }),
    )
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(jwks_uri) { raise Faraday::ConnectionFailed, "refused" }
      end
    before_count = RpBaseAppEventReceipt.count

    stub_outbound_http(stubs) { post("/oidc/closures", params: { logout_token: }) }
    stubs.verify_stubbed_calls

    assert_response :service_unavailable
    assert_nil rp_session.reload.revoked_at
    assert_equal before_count, RpBaseAppEventReceipt.count
  ensure
    if defined?(jwks_uri) && jwks_uri.present?
      previous_jwks_client ? OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client :
        OidcOpJwksClient::CLIENTS.delete(jwks_uri)
    end
  end

  test "a Visa Org Logout Token revokes only Base Org sessions in rp_base_org" do
    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    https!
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host, default_scheme: "https",
    )
    cell = RpCellBinding.fetch("rp_base_org")
    sid = SecureRandom.uuid
    rp_session = seed_rp_cell_session(
      cell:, issuer: visa_origin.origin, subject: "base-org-logout-subject", sid:, absolute_expires_at: 1.hour.from_now,
    )
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    claims = {
      "iss" => visa_origin.origin,
      "aud" => [cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => SecureRandom.uuid,
      "sid" => sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    logout_token = JWT.encode(
      claims, signing_key, JitSecurityJwtJwk::ALGORITHM,
      { "kid" => "base-org-logout-#{SecureRandom.hex(8)}", "typ" => "logout+jwt" },
    )
    public_jwk = JitSecurityJwtJwk.export_public(
      signing_key,
      kid: JWT.decode(logout_token, nil, false).last.fetch("kid"),
    )
    jwks_uri = visa_origin.jwks_uri
    previous_jwks_client = OidcOpJwksClient::CLIENTS[jwks_uri]
    OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
      jwks_uri:, limiter: OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current }),
    )
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(jwks_uri) { [200, { "Content-Type" => "application/json" }, JSON.generate("keys" => [public_jwk])] }
      end

    stub_outbound_http(stubs) { post("/oidc/closures", params: { logout_token: }) }
    stubs.verify_stubbed_calls

    assert_response :ok
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate rp_session.reload.revoked_at, :present?
    binding = RpBaseOrgOpSessionBinding.find_by!(issuer: visa_origin.origin, sid:)

    assert_predicate binding.revoked_at, :present?
    assert_equal "org", binding.realm
    assert_equal cell.client_id, binding.client_id
    assert_equal 1, RpBaseOrgEventReceipt.where(client_id: cell.client_id).count

    post("/oidc/closures", params: { logout_token: })

    assert_response :ok
    assert_equal 1, RpBaseOrgEventReceipt.where(client_id: cell.client_id).count
  ensure
    if defined?(jwks_uri) && jwks_uri.present?
      previous_jwks_client ? OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client :
        OidcOpJwksClient::CLIENTS.delete(jwks_uri)
    end
  end
end
