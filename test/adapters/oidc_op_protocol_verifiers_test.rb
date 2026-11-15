# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcOpProtocolVerifiersTest < ActiveSupport::TestCase
  CLIENT_ID = "base-app-ww"
  ISSUER = "https://visa.umaxica.app"
  NONCE = "rp-generated-nonce"
  PROFILE_CLAIMS = %w(iss sub aud exp iat auth_time nonce jti sid acr amr).freeze

  class FixedJwksClient
    attr_reader :lookups

    def initialize(key)
      @key = key
      @lookups = []
    end

    def lookup(kid)
      lookups << kid
      OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil)
    end
  end

  setup do
    @key = OpenSSL::PKey::RSA.generate(3072)
    @jwks_client = FixedJwksClient.new(@key)
  end

  test "the front-channel ID token accepts the exact Base App profile without typ act or nbf" do
    result = verify_id_token(sign_id_token(header: { "kid" => "id-token-test" }))

    assert_predicate result, :success?
    assert_equal "visa-subject", result.payload.fetch("sub")
    assert_equal PROFILE_CLAIMS.sort, result.payload.keys.sort
    assert_equal ["id-token-test"], @jwks_client.lookups
  end

  test "the front-channel ID token accepts the exact Base Org profile" do
    client_id = RpCellBinding.fetch("rp_base_org").client_id
    issuer = "https://visa.umaxica.org"
    result = verify_id_token(
      sign_id_token(client_id:, issuer:), client_id:, realm: "org", issuer:,
    )

    assert_predicate result, :success?
    assert_equal [client_id], result.payload.fetch("aud")
  end

  test "PS256 tokens below and at the two-minute lifetime boundary are accepted and longer tokens are refused" do
    now = Time.current.to_i
    below = verify_id_token(sign_id_token(claims: { "iat" => now, "exp" => now + 119 }))
    accepted = verify_id_token(sign_id_token(claims: { "iat" => now, "exp" => now + 120 }))
    refused = verify_id_token(sign_id_token(claims: { "iat" => now, "exp" => now + 121 }))

    assert_predicate below, :success?
    assert_predicate accepted, :success?
    assert_not_predicate refused, :success?
    assert_equal "lifetime", refused.detail
  end

  test "another signing algorithm is refused before a JWKS lookup" do
    token = sign_id_token
    encoded_header, payload, signature = token.split(".")
    header = JSON.parse(Base64.urlsafe_decode64(encoded_header)).merge("alg" => "RS256")
    tampered_header = Base64.urlsafe_encode64(JSON.generate(header), padding: false)

    result = verify_id_token([tampered_header, payload, signature].join("."))

    assert_not_predicate result, :success?
    assert_empty @jwks_client.lookups
  end

  test "an invalid PS256 signature is refused after the issuer key lookup" do
    other_key = OpenSSL::PKey::RSA.generate(3072)
    token = sign_id_token(key: other_key)

    result = verify_id_token(token)

    assert_not_predicate result, :success?
    assert_equal ["id-token-test"], @jwks_client.lookups
  end

  test "wrong issuer, audience and nonce are refused" do
    invalid_claims = [
      { "iss" => "https://visa.umaxica.org" },
      { "aud" => ["another-client"] },
      { "nonce" => "another-nonce" },
    ]

    invalid_claims.each do |claims|
      result = verify_id_token(sign_id_token(claims:))

      assert_not_predicate result, :success?, claims.keys.first
    end
  end

  test "missing sid, missing required claims, and extra claims are refused" do
    invalid_claims = [
      { "sid" => nil },
      { "nonce" => nil },
      { "amr" => nil },
      { "email" => "personal-data@example.test" },
    ]

    invalid_claims.each do |claims|
      result = verify_id_token(sign_id_token(claims:))

      assert_not_predicate result, :success?, claims.keys.first
    end
  end

  test "expired, future-issued and empty authentication claims are refused" do
    now = Time.current.to_i
    invalid_claims = [
      { "exp" => now - 1 },
      { "iat" => now + OidcOpIdTokenVerifier::CLOCK_SKEW_LEEWAY_SECONDS + 1 },
      { "acr" => "" },
      { "amr" => [] },
    ]

    invalid_claims.each do |claims|
      result = verify_id_token(sign_id_token(claims:))

      assert_not_predicate result, :success?, claims.keys.first
    end
  end

  private

  def verify_id_token(token, client_id: CLIENT_ID, realm: "app", issuer: ISSUER)
    OidcOpIdTokenVerifier.new(
      id_token: token, client_id:, realm:, issuer:,
      expected_nonce: NONCE, jwks_client: @jwks_client,
    ).call
  end

  def sign_id_token(claims: {}, client_id: CLIENT_ID, issuer: ISSUER, header: {}, key: @key)
    now = Time.current.to_i
    payload = {
      "iss" => issuer,
      "aud" => [client_id],
      "exp" => now + 120,
      "iat" => now,
      "sub" => "visa-subject",
      "nonce" => NONCE,
      "jti" => SecureRandom.uuid,
      "sid" => "visa-session",
      "acr" => "urn:umaxica:base:normal",
      "amr" => ["pwd"],
      "auth_time" => now,
    }.merge(claims).compact
    JWT.encode(payload, key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "id-token-test" }.merge(header))
  end
end
