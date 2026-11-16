# typed: false
# frozen_string_literal: true

require "jwt"

# Signed, short-lived authorization state for the Base App RP.
module OidcStateJwt
  module_function

  TOKEN_TYPE = "umaxica-oidc-state+jwt"
  AUDIENCE_SUFFIX = "#oidc-state"
  TTL = 30.minutes
  VERSION = 1
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  REQUIRED_CLAIMS = %w(iss aud jti iat exp v).freeze

  Verification =
    Data.define(:valid, :jti, :target_link_uri, :reason) do
      def valid? = valid
    end

  def issue(client_id:, target_link_uri:, now: Time.current, jti: SecureRandom.uuid)
    target = RpTargetLinkUri.normalize(target_link_uri)
    raise ArgumentError, "OIDC state target must be a path on this RP" if target_link_uri.present? && target.nil?

    payload = {
      "iss" => client_id.to_s,
      "aud" => audience_for(client_id),
      "jti" => jti,
      "iat" => now.to_i,
      "exp" => (now + TTL).to_i,
      "v" => VERSION,
    }
    payload["target_link_uri"] = target if target.present?
    [JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: issuer_id_for(client_id)), jti]
  end

  def verify(client_id:, token:)
    _payload, header = JWT.decode(token.to_s, nil, false)
    return refused("invalid_header") unless header.is_a?(Hash) &&
      header["alg"] == JitSecurityJwtJwk::ALGORITHM && header["typ"] == TOKEN_TYPE &&
      header["kid"].is_a?(String) && header["kid"].present?

    key = JitSecurityJwtRegistry.public_key_for(issuer_id_for(client_id), header["kid"])
    return refused("unknown_key") unless key

    payload, = JWT.decode(
      token.to_s, key, true,
      algorithms: [JitSecurityJwtJwk::ALGORITHM], required_claims: REQUIRED_CLAIMS,
      verify_iss: true, iss: client_id.to_s, verify_aud: true, aud: audience_for(client_id),
      verify_expiration: true, verify_iat: { leeway: CLOCK_SKEW_LEEWAY_SECONDS }, leeway: 0,
    )
    return refused("unsupported_version") unless payload["v"] == VERSION
    return refused("invalid_target") if payload["target_link_uri"].present? &&
      RpTargetLinkUri.normalize(payload["target_link_uri"]) != payload["target_link_uri"]

    Verification.new(valid: true, jti: payload.fetch("jti"), target_link_uri: payload["target_link_uri"], reason: nil)
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError, ArgumentError, TypeError, KeyError
    refused("invalid_token")
  end

  def audience_for(client_id) = "#{client_id}#{AUDIENCE_SUFFIX}"

  def issuer_id_for(client_id)
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    raise JitSecurityJwtRegistry::ConfigurationError, "no OIDC client key namespace" if namespace.blank?

    "oidc_client:#{namespace}"
  end

  def refused(reason) = Verification.new(valid: false, jti: nil, target_link_uri: nil, reason:)
  private_class_method :audience_for, :issuer_id_for, :refused
end
