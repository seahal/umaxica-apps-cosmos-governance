# typed: false
# frozen_string_literal: true

require "jwt"

# Verifies the fixed Visa Back-Channel Logout Token contract for one Base RP client.
class OidcOpLogoutTokenVerifier
  Result =
    Data.define(:success, :payload, :error) do
      def success? = success

      def key_unavailable? = error == "key_unavailable"
    end

  ALGORITHM = JitSecurityJwtJwk::ALGORITHM
  TOKEN_TYPE = "logout+jwt"
  EVENT = "http://schemas.openid.net/event/backchannel-logout"
  REQUIRED_CLAIMS = %w(iss aud iat exp jti sid events).freeze
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  MAX_LIFETIME_SECONDS = 300
  MAX_IDENTIFIER_LENGTH = 255
  ALLOWED_HEADER_KEYS = %w(alg kid typ).freeze

  def initialize(logout_token:, client_id:, issuer:, jwks_client:)
    @logout_token = logout_token
    @client_id = client_id
    @issuer = issuer
    @jwks_client = jwks_client
  end

  public

  def call
    return failure if logout_token.blank?

    unverified_payload, header = JWT.decode(logout_token, nil, false)
    return failure unless valid_header?(header)
    return failure unless unverified_payload.is_a?(Hash) && unverified_payload["iss"] == issuer

    lookup = jwks_client.lookup(header.fetch("kid"))
    return failure("key_unavailable") if lookup.unavailable?
    return failure unless lookup.found?

    payload, = JWT.decode(
      logout_token, lookup.key, true,
      algorithms: [ALGORITHM], required_claims: REQUIRED_CLAIMS,
      leeway: CLOCK_SKEW_LEEWAY_SECONDS,
      verify_iat: { leeway: CLOCK_SKEW_LEEWAY_SECONDS },
      verify_iss: true, iss: issuer, verify_aud: true, aud: client_id,
      verify_expiration: true,
    )
    valid_claims?(payload) ? Result.new(success: true, payload:, error: nil) : failure
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, ArgumentError, KeyError, TypeError
    failure
  end

  private

  attr_reader :logout_token, :client_id, :issuer, :jwks_client

  def valid_header?(header)
    header.is_a?(Hash) && header.size == ALLOWED_HEADER_KEYS.size &&
      ALLOWED_HEADER_KEYS.all? { |key| header.key?(key) } &&
      header["alg"] == ALGORITHM && header["typ"] == TOKEN_TYPE &&
      header["kid"].is_a?(String) && header["kid"].present? &&
      header["kid"].bytesize <= OidcOpJwksClient::MAXIMUM_KID_LENGTH
  end

  def valid_claims?(payload)
    return false unless payload.is_a?(Hash)
    return false if payload.key?("nonce")
    return false unless payload["aud"].is_a?(Array) && payload["aud"] == [client_id]
    return false unless payload["events"].is_a?(Hash) && payload["events"][EVENT].is_a?(Hash)
    return false unless bounded_identifier?(payload["sid"])
    return false unless bounded_identifier?(payload["jti"])

    issued_at = payload["iat"]
    expires_at = payload["exp"]
    issued_at.is_a?(Numeric) && expires_at.is_a?(Numeric) &&
      expires_at > issued_at && expires_at - issued_at <= MAX_LIFETIME_SECONDS
  end

  def bounded_identifier?(value)
    value.is_a?(String) && value.present? && value.bytesize <= MAX_IDENTIFIER_LENGTH
  end

  def failure(error = "invalid_token")
    Result.new(success: false, payload: nil, error:)
  end
end
