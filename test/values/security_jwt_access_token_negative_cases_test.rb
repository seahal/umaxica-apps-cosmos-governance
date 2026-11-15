# typed: false
# frozen_string_literal: true

require "test_helper"

# Negative verification cases for RFC 9068 auth access tokens. Each case
# re-signs an otherwise valid token with one defect and asserts fail-closed behavior.
class SecurityJwtAccessTokenNegativeCasesTest < ActiveSupport::TestCase
  AUTH_HOST = "example.com"

  # --- auth_access -----------------------------------------------------------

  test "auth access accepts PS256 and rejects ES384, RS256, PS384, none, HMAC, and header mismatch" do
    payload, header = auth_parts
    signing_key = AuthenticationJwtConfiguration.private_key
    token = JWT.encode(payload, signing_key, "PS256", header)

    assert_equal "PS256", header.fetch("alg")
    assert_predicate decode_auth(token), :present?

    es384 = JWT.encode(
      payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384", header.merge("alg" => "ES384"),
    )
    rs256 = JWT.encode(payload, signing_key, "RS256", header.merge("alg" => "RS256"))
    ps384 = JWT.encode(payload, signing_key, "PS384", header.merge("alg" => "PS384"))
    hmac = JWT.encode(payload, "shared-secret", "HS256", header.merge("alg" => "HS256"))
    none = JWT.encode(payload, nil, "none", header.merge("alg" => "none"))
    parts = token.split(".")
    parts[0] = Base64.urlsafe_encode64(header.merge("alg" => "ES384").to_json, padding: false)
    header_mismatch = parts.join(".")

    {
      "ES384" => es384,
      "RS256" => rs256,
      "PS384" => ps384,
      "none" => none,
      "HMAC" => hmac,
      "PS256 signature with ES384 header" => header_mismatch,
    }.each do |label, invalid_token|
      assert_nil decode_auth(invalid_token), "#{label} must be rejected"
    end
  end

  test "auth access rejects wrong issuer and audience when signed by the shared repository key" do
    payload, header = auth_parts
    key = JitSecurityJwtRegistry.private_key_for("surface:BASE_APP")
    wrong_issuer = JWT.encode(payload.merge("iss" => "https://www.umaxica.app"), key, "PS256", header)
    wrong_audience = JWT.encode(payload.merge("aud" => ["other-resource"]), key, "PS256", header)

    assert_nil decode_auth(wrong_issuer)
    assert_nil decode_auth(wrong_audience)
  end

  test "auth access rejects malformed and missing required claims" do
    variants = {
      "client_id missing" => ->(p) { p.except("client_id") },
      "client_id not a string" => ->(p) { p.merge("client_id" => 7) },
      "exp missing" => ->(p) { p.except("exp") },
      "jti missing" => ->(p) { p.except("jti") },
      "iss missing" => ->(p) { p.except("iss") },
      "aud empty" => ->(p) { p.merge("aud" => []) },
      "iat as float" => ->(p) { p.merge("iat" => p["iat"] + 0.5) },
      "sub numeric" => ->(p) { p.merge("sub" => clients(:one).id) },
      "scope as array" => ->(p) { p.merge("scope" => p["scope"].split) },
      "scope missing" => ->(p) { p.except("scope") },
      "future nbf" => ->(p) { p.merge("nbf" => 10.minutes.from_now.to_i) },
    }

    variants.each do |label, mutate|
      assert_nil decode_auth(resign_auth(&mutate)), "#{label} must be rejected"
    end
  end

  test "auth access rejects legacy scp, act, and payload typ claims" do
    assert_nil decode_auth(resign_auth { |p| p.merge("scp" => p["scope"].split) })
    assert_nil decode_auth(resign_auth { |p| p.merge("act" => "client") })
    assert_nil decode_auth(resign_auth { |p| p.merge("typ" => "auth-access-token;client") })
  end

  test "auth access rejects a token whose domain scope names another resource type" do
    payload = decode_auth(resign_auth { |p| p.merge("scope" => "authenticated domain:operator") })

    assert_not AuthenticationTokenService.resource_type_scope_matches?(payload, "client")
  end

  test "auth access rejects a legacy custom-typ token end to end" do
    payload, header = auth_parts
    legacy = JWT.encode(
      payload.merge("scp" => payload["scope"].split, "act" => "client", "sub" => clients(:one).id),
      AuthenticationJwtConfiguration.private_key,
      "PS256",
      header.merge("typ" => "auth-access-token;client"),
    )

    assert_nil decode_auth(legacy)
  end

  test "local issuers are environment specific" do
    assert_equal "urn:umaxica:test:auth", AuthenticationJwtConfiguration.issuer
    assert_nil decode_auth(resign_auth { |p| p.merge("iss" => "urn:umaxica:development:auth") })
  end

  test "production boot validation rejects development and test issuers" do
    with_production do
      error = assert_raises(ArgumentError) { AuthenticationJwtConfiguration.validate! }

      assert_match(/AUTH_JWT_ISSUER must not include non-production identifiers/, error.message)
    end
  end

  test "production boot validation accepts production identifiers" do
    with_env("AUTH_JWT_ISSUER" => "https://sign.umaxica.app") do
      with_production do
        assert AuthenticationJwtConfiguration.validate!
      end
    end
  end

  test "retired and unknown auth resource types are refused" do
    [nil, "", "visitor", "unknown"].each do |resource_type|
      assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences(resource_type) }
      assert_raises(ArgumentError) { AuthenticationJwtConfiguration.client_id(resource_type) }
    end
  end

  test "leeway is fixed and not read from the environment" do
    with_env("AUTH_JWT_LEEWAY_SECONDS" => "86400") do
      assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                   AuthenticationJwtConfiguration.leeway_seconds
    end
  end

  test "keyring encode requires an explicit JOSE typ and ignores payload typ" do
    assert_raises(ArgumentError) { JitSecurityJwtKeyring.encode({ "typ" => "x+jwt" }, typ: nil) }

    token = JitSecurityJwtKeyring.encode({ "typ" => "payload-typ" }, typ: "at+jwt")

    assert_equal "at+jwt", JWT.decode(token, nil, false)[1]["typ"]
  end

  private

  def auth_parts
    payload = {
      "iss" => AuthenticationJwtConfiguration.issuer,
      "aud" => AuthenticationJwtConfiguration.audiences("client"),
      "sub" => "external-client-subject",
      "client_id" => AuthenticationJwtConfiguration.client_id("client"),
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 10.minutes.from_now.to_i,
      "jti" => "external-token-id",
      "sid" => "external-session-id",
      "acr" => "aal1",
      "scope" => "authenticated domain:client read:self write:self",
    }
    token = JWT.encode(
      payload, AuthenticationJwtConfiguration.private_key, "PS256",
      { "typ" => "at+jwt", "kid" => JitSecurityJwtKeyring.active_kid },
    )

    assert_predicate decode_auth(token), :present?
    JWT.decode(token, nil, false)
  end

  def resign_auth
    payload, header = auth_parts
    JWT.encode(yield(payload), AuthenticationJwtConfiguration.private_key, "PS256", header)
  end

  def decode_auth(token)
    AuthenticationTokenService.decode(token, host: AUTH_HOST, resource_type: "client")
  end

  def with_production(&)
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production"), &)
  end

  def with_env(vars)
    originals = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
