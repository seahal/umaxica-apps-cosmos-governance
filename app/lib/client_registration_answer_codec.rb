# typed: false
# frozen_string_literal: true

require "jwt"

# Encodes Governance's registration answers (H2, H4, H6) as PS256 JWS signed with the Base App key,
# which Base publishes at /.well-known/jwks.json. Claim names follow the approved wire shape in
# docs/pending-registration-routes-contract.md.
module ClientRegistrationAnswerCodec
  module_function

  TOKEN_TYPE = "registration-answer+jwt"
  TTL_SECONDS = 120
  JWT_NAMESPACE = "BASE_APP"
  REASONS = %w(
    started completed cancelled sign_in_instead ineligible credential_rejected conflict not_active unavailable
  ).freeze
  REPLIES_TO = %w(start credential cancellation).freeze
  OUTSTANDING_REQUIREMENT = "passkey"

  def encode(reason:, replies_to:, ceremony_digest:, issuer:, audience:, registration: nil, completion: nil,
             now: Time.current)
    reason = reason.to_s
    raise ArgumentError, "unsupported answer reason" unless REASONS.include?(reason)
    raise ArgumentError, "unsupported answered handoff" unless REPLIES_TO.include?(replies_to)

    issued_at = now.to_i
    payload = {
      "iss" => issuer, "aud" => audience, "iat" => issued_at, "exp" => issued_at + TTL_SECONDS,
      "jti" => SecureRandom.uuid, "cer" => ceremony_digest, "rto" => replies_to, "rsn" => reason,
    }
    payload["reg"] = registration.public_id if registration
    case reason
    when "started"
      payload.merge!(
        "uhd" => registration.webauthn_user_handle, "req" => OUTSTANDING_REQUIREMENT,
        "dl" => registration.deadline_at.to_i,
      )
    when "completed"
      subject = completion.client.public_id
      payload.merge!(
        "sub" => subject, "act" => subject, "rcp" => completion.public_id, "mth" => registration.method_key,
      )
    when "cancelled", "sign_in_instead", "ineligible", "credential_rejected", "conflict", "not_active",
         "unavailable"
      payload
    else
      raise ArgumentError, "unsupported answer reason"
    end
    JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: JitSecurityJwtRegistry.surface(JWT_NAMESPACE).id)
  end
end
