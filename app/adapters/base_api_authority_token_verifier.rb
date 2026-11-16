# typed: false
# frozen_string_literal: true

require "jwt"

# Verifies a Governance bearer and reloads its RP session from the correct cell writer.
class BaseApiAuthorityTokenVerifier
  Result =
    Data.define(:status, :profile, :session, :principal, :claims, :authentication_payload) do
      def authenticated? = status == :authenticated
    end

  INVALID = :invalid
  private_constant :INVALID

  class << self
    public

    def call(...) = new(...).call
  end

  def initialize(token:, expected_client_id:, expected_audience_resource_type:, now: Time.current)
    @token = token
    @profile = BaseApiAuthorityTokenProfileRegistry.for_client_id(expected_client_id)
    @expected_audience_resource_type = expected_audience_resource_type.to_s
    @now = now.to_i
  end

  public

  def call
    return invalid unless token.is_a?(String) && token.present?

    header = JitSecurityJwtKeyring.parse_header(token)
    return invalid unless valid_header?(header)

    issuer_id = BaseApiAuthorityTokenProfileRegistry.key_issuer_id_for(profile)
    public_key = JitSecurityJwtRegistry.public_key_for(issuer_id, header.fetch("kid"))
    return invalid unless public_key

    claims, = JWT.decode(token, public_key, true, decode_options)
    return invalid unless valid_claims?(claims)

    resolve_active_session(claims)
  rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, JWT::InvalidIssuerError,
         JWT::InvalidAudError, JWT::MissingRequiredClaim, ArgumentError, TypeError, OpenSSL::PKey::PKeyError
    invalid
  end

  private

  attr_reader :token, :profile, :expected_audience_resource_type, :now

  def decode_options
    {
      algorithms: [JitSecurityJwtKeyring::ALGORITHM],
      required_claims: BaseApiAuthorityTokenProfileRegistry::CLAIMS,
      verify_expiration: true,
      verify_iss: true,
      iss: BaseApiAuthorityTokenProfileRegistry.issuer_for(profile),
      verify_aud: true,
      aud: BaseApiAuthorityTokenProfileRegistry.audience_for(expected_audience_resource_type),
      leeway: 0,
    }
  end

  def valid_header?(header)
    header.is_a?(Hash) && header.keys.sort == BaseApiAuthorityTokenProfileRegistry::HEADER_KEYS &&
      header["alg"] == JitSecurityJwtKeyring::ALGORITHM &&
      header["typ"] == BaseApiAuthorityTokenProfileRegistry::TOKEN_TYPE &&
      header["kid"].is_a?(String) && header["kid"].present?
  end

  def valid_claims?(claims)
    return false unless claims.is_a?(Hash) && claims.keys.sort == BaseApiAuthorityTokenProfileRegistry::CLAIMS.sort

    valid_audience_claims?(claims) && valid_client_claims?(claims) && valid_subject_claims?(claims) &&
      valid_session_id_claim?(claims) && valid_time_claims?(claims)
  end

  def valid_audience_claims?(claims)
    expected_audience_resource_type == profile.resource_type &&
      claims["iss"] == BaseApiAuthorityTokenProfileRegistry.issuer_for(profile) &&
      claims["aud"] == BaseApiAuthorityTokenProfileRegistry.audience_for(expected_audience_resource_type) &&
      claims["aud"] == BaseApiAuthorityTokenProfileRegistry.audience_for(profile.resource_type)
  end

  def valid_client_claims?(claims)
    claims["client_id"] == profile.cell.client_id && claims["realm"] == profile.cell.realm
  end

  def valid_subject_claims?(claims)
    claims["sub"].is_a?(String) && claims["sub"].present? && claims["act"] == claims["sub"]
  end

  def valid_session_id_claim?(claims)
    claims["rp_session_id"].is_a?(String) &&
      claims["rp_session_id"].match?(BaseApiAuthorityTokenProfileRegistry::SESSION_ID_FORMAT)
  end

  def valid_time_claims?(claims)
    issued_at = claims["iat"]
    expires_at = claims["exp"]
    issued_at.is_a?(Integer) && expires_at.is_a?(Integer) && issued_at <= now && expires_at > now &&
      expires_at > issued_at &&
      expires_at - issued_at <= BaseApiAuthorityTokenProfileRegistry::MAX_LIFETIME_SECONDS
  end

  def resolve_active_session(claims)
    record_class = profile.record_class
    record_class.connected_to(role: :writing) do
      record_class.uncached do
        session_scope = profile.session_class
        session_scope = session_scope.includes(:authentication_evidence) if profile.authentication_evidence_class
        session = session_scope.includes(op_session_binding: { identity_binding: :principal })
          .find_by(public_id: claims.fetch("rp_session_id"))
        return invalid unless valid_session?(session, claims)

        binding = session.op_session_binding
        identity = binding.identity_binding
        Result.new(
          status: :authenticated,
          profile:,
          session:,
          principal: identity.principal,
          claims: claims.freeze,
          authentication_payload: authentication_payload(binding, identity, session),
        )
      end
    end
  end

  def valid_session?(session, claims)
    return false unless session&.active?(now: profile.record_class.database_now)

    binding = session.op_session_binding
    identity = binding&.identity_binding
    principal = identity&.principal
    return false unless valid_binding?(binding, identity, principal)
    return false unless matching_identity_context?(binding, identity)
    return false unless identity.subject == claims.fetch("sub")

    valid_authentication_evidence?(session)
  end

  def valid_binding?(binding, identity, principal)
    binding && binding.revoked_at.nil? && binding.sid.present? && identity && principal && principal.disabled_at.nil?
  end

  def matching_identity_context?(binding, identity)
    binding.issuer == identity.issuer && BaseApiAuthorityTokenProfileRegistry.op_issuer?(profile, binding.issuer) &&
      binding.realm == profile.cell.realm && identity.realm == profile.cell.realm &&
      binding.client_id == profile.cell.client_id && identity.client_id == profile.cell.client_id
  end

  def valid_authentication_evidence?(session)
    evidence_class = profile.authentication_evidence_class
    return true unless evidence_class

    evidence = session.authentication_evidence
    evidence.instance_of?(evidence_class) &&
      evidence.authentication_context == AuthenticationContextValue::NORMAL_KEY &&
      evidence.acr.present? && evidence.amr.is_a?(Array) && evidence.amr.present? &&
      evidence.amr.all? { |method| method.is_a?(String) && method.present? } && evidence.auth_time.positive?
  end

  def authentication_payload(binding, identity, session)
    evidence_class = profile.authentication_evidence_class
    return unless evidence_class

    evidence = session.authentication_evidence
    {
      "iss" => binding.issuer,
      "sub" => identity.subject,
      "aud" => [profile.cell.client_id],
      "client_id" => profile.cell.client_id,
      "realm" => profile.cell.realm,
      "act" => profile.resource_type,
      "sid" => binding.sid,
      "jti" => evidence.id_token_jti_digest,
      "acr" => evidence.acr,
      "amr" => evidence.amr,
      "auth_time" => evidence.auth_time,
      "authn_ctx" => evidence.authentication_context,
      "iat" => evidence.auth_time,
      "exp" => session.absolute_expires_at.to_i,
    }.freeze
  end

  def invalid
    Result.new(status: INVALID, profile:, session: nil, principal: nil, claims: nil, authentication_payload: nil)
  end
end
