# typed: false
# frozen_string_literal: true

require "jwt"
require "digest"

# Verifies the owner-approved first-party Base RP front-channel ID Token profile.
class OidcOpIdTokenVerifier
  Result =
    Data.define(:success, :payload, :error, :detail) do
      def initialize(success:, payload:, error:, detail: nil) = super

      def success? = success
    end

  ALGORITHM = JitSecurityJwtJwk::ALGORITHM
  REQUIRED_CLAIMS = %w(iss sub aud exp iat auth_time nonce jti sid acr amr).freeze
  ALLOWED_CLAIMS = REQUIRED_CLAIMS.freeze
  RESOURCE_TYPE_BY_REALM = { "app" => "client", "org" => "operator" }.freeze
  MAX_LIFETIME_SECONDS = 2.minutes.to_i
  CLOCK_SKEW_LEEWAY_SECONDS = 30

  def initialize(id_token:, client_id:, realm:, issuer:, expected_nonce:, jwks_client:)
    @id_token = id_token
    @client_id = require_string(client_id, "client_id")
    @realm = require_realm(realm)
    @issuer = require_string(issuer, "issuer")
    @expected_nonce = require_string(expected_nonce, "expected_nonce")
    @jwks_client = jwks_client
    validate_cell_binding!
  end

  public

  def call
    return failure("missing_id_token") if id_token.blank?

    unverified_payload, header = JWT.decode(id_token, nil, false)
    return failure("invalid_header", detail: "header") unless valid_header?(header)
    return failure("invalid_id_token", detail: "issuer") unless
      unverified_payload.is_a?(Hash) && unverified_payload["iss"] == issuer

    lookup = jwks_client.lookup(header.fetch("kid"))
    return failure("key_unavailable", detail: "jwks_unavailable") if lookup.unavailable?
    return failure("invalid_id_token", detail: "kid_not_found") unless lookup.found?

    payload, = JWT.decode(id_token, lookup.key, true, decode_options)
    claim_failure = failed_claim_check(payload)
    return failure("invalid_id_token", detail: claim_failure) if claim_failure

    Result.new(success: true, payload:, error: nil)
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
    failure("invalid_id_token", detail: e.class.name)
  end

  private

  attr_reader :id_token, :client_id, :realm, :issuer, :expected_nonce, :jwks_client

  def require_string(value, name)
    return value if value.is_a?(String) && value.present?

    raise ArgumentError, "#{name} must be a nonblank string"
  end

  def require_realm(value)
    normalized = value.to_s
    return normalized if RESOURCE_TYPE_BY_REALM.key?(normalized)

    raise ArgumentError, "unsupported RP realm"
  end

  def validate_cell_binding!
    return if RpCellBinding.for_client(client_id).realm == realm

    raise ArgumentError, "client_id is not registered for the RP realm"
  end

  def valid_header?(header)
    header.is_a?(Hash) && header["alg"] == ALGORITHM &&
      header["kid"].is_a?(String) && header["kid"].present? &&
      (header.keys.map(&:to_s) & %w(crit jku jwk x5u x5c zip)).empty?
  end

  def decode_options
    {
      algorithms: [ALGORITHM],
      required_claims: REQUIRED_CLAIMS,
      leeway: 0,
      verify_expiration: true,
      verify_not_before: false,
      verify_iat: false,
      verify_iss: true,
      iss: issuer,
      verify_aud: true,
      aud: client_id,
    }
  end

  def failed_claim_check(payload)
    return "payload_shape" unless payload.is_a?(Hash)
    return "claim_set" unless valid_claim_set?(payload)
    return "string_claims" unless valid_string_claims?(payload)
    return "time_claims" unless valid_time_claims?(payload)
    return "amr" unless valid_amr?(payload)
    return "aud" unless payload["aud"] == [client_id]
    return "iss" unless payload["iss"] == issuer
    return "lifetime" unless lifetime_valid?(payload)
    return "auth_time" unless authentication_time_valid?(payload)
    return "nonce" unless secure_equal?(Digest::SHA256.hexdigest(payload["nonce"]), Digest::SHA256.hexdigest(expected_nonce))

    nil
  end

  def valid_claim_set?(payload)
    payload.keys.all? { |claim| ALLOWED_CLAIMS.include?(claim) } && ALLOWED_CLAIMS.all? { |claim| payload.key?(claim) }
  end

  def valid_string_claims?(payload)
    %w(iss sub nonce jti sid acr).all? do |claim|
      payload[claim].is_a?(String) && payload[claim].present?
    end
  end

  def valid_time_claims?(payload)
    %w(exp iat auth_time).all? { |claim| payload[claim].is_a?(Integer) }
  end

  def valid_amr?(payload)
    payload["amr"].is_a?(Array) && payload["amr"].present? &&
      payload["amr"].all? { |method| method.is_a?(String) && method.present? }
  end

  def lifetime_valid?(payload)
    now = Time.current.to_i
    payload["exp"] > now && payload["iat"] <= now + CLOCK_SKEW_LEEWAY_SECONDS &&
      payload["exp"] > payload["iat"] && payload["exp"] - payload["iat"] <= MAX_LIFETIME_SECONDS
  end

  def authentication_time_valid?(payload)
    payload["auth_time"] <= Time.current.to_i + CLOCK_SKEW_LEEWAY_SECONDS &&
      payload["auth_time"] <= payload["iat"] + CLOCK_SKEW_LEEWAY_SECONDS
  end

  def secure_equal?(actual, expected)
    actual.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def failure(error, detail: nil)
    Result.new(success: false, payload: nil, error:, detail:)
  end
end
