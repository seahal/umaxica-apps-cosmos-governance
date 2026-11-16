# frozen_string_literal: true

require "test_helper"

class OidcOpLogoutTokenVerifierTest < ActiveSupport::TestCase
  CLIENT_ID = "base-app-ww"
  ISSUER = "https://visa.umaxica.app"

  class FixedJwksClient
    def initialize(key)
      @key = key
    end

    public

    def lookup(_kid)
      OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil)
    end
  end

  setup do
    @key = OpenSSL::PKey::RSA.generate(3072)
    @jwks_client = FixedJwksClient.new(@key.public_key)
  end

  test "a Visa PS256 Logout Token with the exact client audience and sid is accepted" do
    now = Time.current.to_i
    claims = {
      "iss" => ISSUER,
      "aud" => [CLIENT_ID],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "logout-event-1",
      "sid" => "visa-sid-1",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    token = JWT.encode(claims, @key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "logout-test", "typ" => "logout+jwt" })
    result = OidcOpLogoutTokenVerifier.new(
      logout_token: token, client_id: CLIENT_ID, issuer: ISSUER, jwks_client: @jwks_client,
    ).call

    assert_predicate result, :success?
    assert_equal "visa-sid-1", result.payload.fetch("sid")
  end

  test "ES384, RS256 and PS384 Logout Tokens are refused" do
    now = Time.current.to_i
    claims = {
      "iss" => ISSUER,
      "aud" => [CLIENT_ID],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "logout-event-2",
      "sid" => "visa-sid-2",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    token = JWT.encode(claims, @key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "logout-test", "typ" => "logout+jwt" })
    encoded_header, payload, signature = token.split(".")

    %w(ES384 RS256 PS384).each do |algorithm|
      header = JSON.parse(Base64.urlsafe_decode64(encoded_header)).merge("alg" => algorithm)
      tampered_header = Base64.urlsafe_encode64(JSON.generate(header), padding: false)
      result = OidcOpLogoutTokenVerifier.new(
        logout_token: [tampered_header, payload, signature].join("."), client_id: CLIENT_ID,
        issuer: ISSUER, jwks_client: @jwks_client,
      ).call

      assert_not_predicate result, :success?, algorithm
    end
  end

  test "wrong audience, nonce, missing logout event, expired time and overlong lifetime are refused" do
    now = Time.current.to_i
    invalid_claims = [
      { "aud" => ["foreign-client"] },
      { "aud" => CLIENT_ID },
      { "nonce" => "unexpected" },
      { "events" => { "wrong-event" => {} } },
      { "exp" => now - OidcOpLogoutTokenVerifier::CLOCK_SKEW_LEEWAY_SECONDS - 1 },
      { "exp" => now + OidcOpLogoutTokenVerifier::MAX_LIFETIME_SECONDS + 1 },
    ]

    invalid_claims.each do |claim_override|
      claims = {
        "iss" => ISSUER,
        "aud" => [CLIENT_ID],
        "iat" => now,
        "exp" => now + 120,
        "jti" => SecureRandom.uuid,
        "sid" => "visa-sid-3",
        "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
      }.merge(claim_override)
      token = JWT.encode(
        claims, @key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "logout-test", "typ" => "logout+jwt" },
      )
      result = OidcOpLogoutTokenVerifier.new(
        logout_token: token, client_id: CLIENT_ID, issuer: ISSUER, jwks_client: @jwks_client,
      ).call

      assert_not_predicate result, :success?, claim_override.keys.first
    end
  end
end
