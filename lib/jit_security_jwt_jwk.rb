# typed: false
# frozen_string_literal: true

require "jwt"
require "openssl"

module JitSecurityJwtJwk
  module_function

  ALGORITHM = "PS256"
  MIN_RSA_MODULUS_BITS = 3_072
  REQUIRED_PUBLIC_FIELDS = %w(kid alg use kty n e).freeze
  PRIVATE_FIELDS = %w(d p q dp dq qi oth k).freeze

  Error = Class.new(StandardError)

  def normalize_public(entry)
    raise Error, "entry must be a JSON object" unless entry.is_a?(Hash)

    source_hash = entry.stringify_keys
    if PRIVATE_FIELDS.any? { |field| source_hash.key?(field) }
      raise Error, "entry #{source_hash["kid"].inspect} contains private JWK material"
    end

    jwk = source_hash.slice(*(REQUIRED_PUBLIC_FIELDS + ["state"]))
    validate_public!(jwk)
    jwk
  end

  def validate_public!(jwk)
    missing = REQUIRED_PUBLIC_FIELDS.reject { |field| jwk[field].present? }
    raise Error, "public JWK is missing #{missing.join(", ")}" if missing.present?
    raise Error, "public JWK alg must be #{ALGORITHM}" unless jwk["alg"] == ALGORITHM
    raise Error, "public JWK use must be sig" unless jwk["use"] == "sig"
    raise Error, "public JWK kty must be RSA" unless jwk["kty"] == "RSA"

    public_key = JWT::JWK.import(jwk).public_key
    raise Error, "public JWK modulus must be at least #{MIN_RSA_MODULUS_BITS} bits" if
      public_key.n.num_bits < MIN_RSA_MODULUS_BITS
  rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError => e
    raise Error, "contains invalid RSA public JWK material: #{e.class.name}"
  end

  def export_public(key, kid:)
    validate_private_key!(key)

    JWT::JWK.new(key, kid: kid).export.stringify_keys.except(*PRIVATE_FIELDS).merge(
      "alg" => ALGORITHM,
      "use" => "sig",
    )
  end

  def import_public_key(jwk)
    validate_public!(jwk)
    JWT::JWK.import(jwk.except("state")).public_key
  rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError => e
    raise Error, "contains invalid RSA public JWK material: #{e.class.name}"
  end

  def validate_private_key!(key)
    raise Error, "signing key must be RSA" unless key.is_a?(OpenSSL::PKey::RSA)
    raise Error, "RSA signing key must have at least #{MIN_RSA_MODULUS_BITS} bits" if
      key.n.num_bits < MIN_RSA_MODULUS_BITS
  end
end
