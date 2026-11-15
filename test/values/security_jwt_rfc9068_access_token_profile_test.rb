# typed: false
# frozen_string_literal: true

require "test_helper"

class SecurityJwtRfc9068AccessTokenProfileTest < ActiveSupport::TestCase
  test "structural claim validation accepts scalar audiences and rejects invalid audience shapes" do
    payload = {
      "iss" => "https://issuer.example",
      "exp" => 1.hour.from_now.to_i,
      "aud" => "client-audience",
      "sub" => "subject",
      "client_id" => "client-id",
      "iat" => Time.current.to_i,
      "jti" => "token-id",
      "scope" => "domain:client",
    }

    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => ["client-audience"]))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => []))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => ["client", 1]))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => 1))
  end

  test "auth access verification rejects wrong JOSE typ, missing typ, and none alg" do
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

    assert_predicate AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client"),
                     :present?

    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key

    wrong_typ = JWT.encode(payload, key, "PS256", header.merge("typ" => "auth-access-token;client"))
    missing_typ = JWT.encode(payload, key, "PS256", header.except("typ"))
    none_alg = JWT.encode(payload, nil, "none", header.merge("alg" => "none"))

    assert_nil AuthenticationTokenService.decode(wrong_typ, host: "example.com", resource_type: "client")
    assert_nil AuthenticationTokenService.decode(missing_typ, host: "example.com", resource_type: "client")
    assert_nil AuthenticationTokenService.decode(none_alg, host: "example.com", resource_type: "client")
  end

  test "auth access verification rejects expired tokens and wrong issuer or audience" do
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

    assert_predicate AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client"),
                     :present?

    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key

    expired = JWT.encode(payload.merge("exp" => 1.hour.ago.to_i), key, "PS256", header)
    wrong_iss = JWT.encode(payload.merge("iss" => "urn:umaxica:other:auth"), key, "PS256", header)
    wrong_aud = JWT.encode(payload.merge("aud" => ["not-this-resource"]), key, "PS256", header)

    assert_nil AuthenticationTokenService.decode(expired, host: "example.com", resource_type: "client")
    assert_nil AuthenticationTokenService.decode(wrong_iss, host: "example.com", resource_type: "client")
    assert_nil AuthenticationTokenService.decode(wrong_aud, host: "example.com", resource_type: "client")
  end

  test "auth access verification rejects a development issuer when expecting the test issuer" do
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

    assert_predicate AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client"),
                     :present?

    payload, header = JWT.decode(token, nil, false)
    key = AuthenticationJwtConfiguration.private_key
    foreign = JWT.encode(
      payload.merge("iss" => "urn:umaxica:development:auth"),
      key,
      "PS256",
      header,
    )

    assert_nil AuthenticationTokenService.decode(foreign, host: "example.com", resource_type: "client")
  end

  test "production auth audience configuration rejects localhost" do
    error =
      assert_raises(ArgumentError) do
        with_env("AUTH_JWT_CLIENT_AUDIENCES" => "umaxica-api-client,app.localhost") do
          Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
            AuthenticationJwtConfiguration.audiences("client")
          end
        end
      end

    assert_match(/non-production identifiers: app\.localhost/, error.message)
  end

  private

  def with_env(vars)
    originals = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
