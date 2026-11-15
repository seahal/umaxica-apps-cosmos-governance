# typed: false
# frozen_string_literal: true

require "jwt"

# Ingress for the Access-issued registration handoffs H1, H3 and H5
# (adr/sign-up-finalization-in-auth.md, Cosmos split amendment; docs/pending-registration-routes-contract.md).
# Verifies the PS256 signature through Auth App JWKS and the exact claim set of the handoff kind.
# It does not consume the jti: the receiving operation inserts the receipt with the state change.
class ClientRegistrationHandoffVerifier
  Result =
    Data.define(:status, :claims, :reason) do
      def verified? = status == :verified

      def unavailable? = status == :unavailable
    end

  ALGORITHM = JitSecurityJwtJwk::ALGORITHM
  TTL_SECONDS = 120
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  COMMON_CLAIMS = %w(iss aud iat exp jti cer).freeze
  CLAIMS = {
    "start" => (COMMON_CLAIMS + %w(mth idf prf bdt)).freeze,
    "credential" => (COMMON_CLAIMS + %w(reg mth cid cpk cal cnt uv be bs trn aag)).freeze,
    "cancellation" => (COMMON_CLAIMS + %w(reg)).freeze,
  }.freeze
  TOKEN_TYPES = {
    "start" => "registration-start+jwt",
    "credential" => "registration-credential+jwt",
    "cancellation" => "registration-cancel+jwt",
  }.freeze
  FORBIDDEN_HEADERS = %w(crit jku jwk x5u x5c zip).freeze
  METHODS = ClientRegistrationCompletionMethod::IDS.keys.freeze
  BASE64URL = /\A[A-Za-z0-9_-]+\z/
  JTI_FORMAT = /\A[\x21-\x7E]{1,128}\z/
  CEREMONY_DIGEST_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  REGISTRATION_REF_FORMAT = /\A[A-Za-z0-9_-]{21}\z/
  AAGUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  BIRTHDATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  MAX_IDENTIFIER_LENGTH = 255
  MAX_CREDENTIAL_ID_BYTES = 1023
  MAX_PUBLIC_KEY_BYTES = 2048
  MAX_TRANSPORTS = 8
  MAX_TRANSPORT_LENGTH = 16

  def initialize(kind:, token:, issuer:, audience:, jwks_client:, now: Time.current)
    @kind = kind.to_s
    raise ArgumentError, "unsupported registration handoff kind" unless CLAIMS.key?(@kind)

    @token = token
    @issuer = issuer
    @audience = audience
    @jwks_client = jwks_client
    @now = now.to_i
  end

  public

  def call
    return invalid("token_missing") unless token.is_a?(String) && token.present? && token.ascii_only?

    unverified, header = JWT.decode(token, nil, false)
    return invalid("header") unless valid_header?(header)
    return invalid("issuer") unless unverified.is_a?(Hash) && unverified["iss"] == issuer

    lookup = jwks_client.lookup(header.fetch("kid"))
    return Result.new(status: :unavailable, claims: nil, reason: lookup.reason) if lookup.unavailable?
    return invalid("kid") unless lookup.found?

    claims, = JWT.decode(token, lookup.key, true, decode_options)
    failure = failed_claim_check(claims)
    return invalid(failure) if failure

    Result.new(status: :verified, claims: claims.freeze, reason: nil)
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
    invalid("decode")
  end

  private

  attr_reader :kind, :token, :issuer, :audience, :jwks_client, :now

  def valid_header?(header)
    header.is_a?(Hash) && header["alg"] == ALGORITHM && header["typ"] == TOKEN_TYPES.fetch(kind) &&
      header["kid"].is_a?(String) && header["kid"].present? && !header.keys.map(&:to_s).intersect?(FORBIDDEN_HEADERS)
  end

  def decode_options
    {
      algorithms: [ALGORITHM], verify_expiration: true, leeway: 0, verify_not_before: false, verify_iat: false,
      verify_iss: true, iss: issuer, verify_aud: true, aud: audience,
    }
  end

  def failed_claim_check(claims)
    return "claim_set" unless claims.is_a?(Hash) && claims.keys.sort == CLAIMS.fetch(kind).sort
    return "aud" unless claims["aud"] == audience
    return "lifetime" unless valid_lifetime?(claims)
    return "jti" unless claims["jti"].is_a?(String) && JTI_FORMAT.match?(claims["jti"])
    return "cer" unless claims["cer"].is_a?(String) && CEREMONY_DIGEST_FORMAT.match?(claims["cer"])

    case kind
    when "start" then failed_start_check(claims)
    when "credential" then failed_credential_check(claims)
    when "cancellation" then failed_reference_check(claims)
    else raise ArgumentError, "unsupported registration handoff kind"
    end
  end

  def valid_lifetime?(claims)
    iat = claims["iat"]
    exp = claims["exp"]
    iat.is_a?(Integer) && exp.is_a?(Integer) && exp - iat == TTL_SECONDS && exp > now &&
      iat <= now + CLOCK_SKEW_LEEWAY_SECONDS
  end

  def failed_start_check(claims)
    return "mth" unless METHODS.include?(claims["mth"])
    return "idf" unless claims["idf"].is_a?(String) && claims["idf"].present? &&
      claims["idf"].length <= MAX_IDENTIFIER_LENGTH
    return "prf" unless claims["prf"].is_a?(Integer) && claims["prf"] <= claims["iat"] + CLOCK_SKEW_LEEWAY_SECONDS
    return "bdt" unless claims["bdt"].is_a?(String) && BIRTHDATE_FORMAT.match?(claims["bdt"])

    nil
  end

  def failed_reference_check(claims)
    return "reg" unless claims["reg"].is_a?(String) && REGISTRATION_REF_FORMAT.match?(claims["reg"])

    nil
  end

  def failed_credential_check(claims)
    reference_failure = failed_reference_check(claims)
    return reference_failure if reference_failure
    return "mth" unless METHODS.include?(claims["mth"])
    return "cid" unless base64url_within?(claims["cid"], MAX_CREDENTIAL_ID_BYTES)
    return "cpk" unless base64url_within?(claims["cpk"], MAX_PUBLIC_KEY_BYTES)
    return "cal" unless claims["cal"].is_a?(Integer)
    return "cnt" unless claims["cnt"].is_a?(Integer) && claims["cnt"] >= 0
    return "flags" unless %w(uv be bs).all? { |flag| [true, false].include?(claims[flag]) }
    return "trn" unless valid_transports?(claims["trn"])
    return "aag" unless claims["aag"].is_a?(String) && AAGUID_FORMAT.match?(claims["aag"])

    nil
  end

  def base64url_within?(value, max_bytes)
    return false unless value.is_a?(String) && BASE64URL.match?(value)

    decoded = Base64.urlsafe_decode64(value)
    decoded.bytesize.between?(1, max_bytes)
  rescue ArgumentError
    false
  end

  def valid_transports?(value)
    value.is_a?(Array) && value.size <= MAX_TRANSPORTS &&
      value.all? { |entry| entry.is_a?(String) && entry.present? && entry.length <= MAX_TRANSPORT_LENGTH }
  end

  def invalid(reason)
    Result.new(status: :invalid, claims: nil, reason:)
  end
end
