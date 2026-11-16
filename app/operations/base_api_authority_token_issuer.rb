# typed: false
# frozen_string_literal: true

# Issues a short-lived Governance bearer from an active, local RP session.
class BaseApiAuthorityTokenIssuer
  class InactiveRpSession < StandardError; end

  class << self
    public

    def issue(rp_session:, audience_resource_type: nil)
      new(rp_session:, audience_resource_type:).issue
    end
  end

  def initialize(rp_session:, audience_resource_type: nil)
    @rp_session = rp_session
    @profile = BaseApiAuthorityTokenProfileRegistry.for_session(rp_session)
    @audience_resource_type = audience_resource_type || @profile.resource_type
    BaseApiAuthorityTokenProfileRegistry.audience_for(@audience_resource_type)
  end

  public

  def issue
    record_class.connected_to(role: :writing) do
      record_class.uncached do
        session_scope = session_class
        session_scope = session_scope.includes(:authentication_evidence) if profile.authentication_evidence_class
        session = session_scope.includes(op_session_binding: { identity_binding: :principal })
          .find_by(id: rp_session.id, public_id: rp_session.public_id)
        raise InactiveRpSession, "RP session is not active for Base API authority" unless valid_session?(session)

        identity = session.op_session_binding.identity_binding
        now = Time.current.to_i
        claims = {
          "iss" => BaseApiAuthorityTokenProfileRegistry.issuer_for(profile),
          "aud" => BaseApiAuthorityTokenProfileRegistry.audience_for(audience_resource_type),
          "sub" => identity.subject,
          "act" => identity.subject,
          "rp_session_id" => session.public_id,
          "client_id" => profile.cell.client_id,
          "realm" => profile.cell.realm,
          "jti" => JitSecurityJwtJtiGenerator.generate,
          "iat" => now,
          "exp" => now + BaseApiAuthorityTokenProfileRegistry::MAX_LIFETIME_SECONDS,
        }
        JitSecurityJwtKeyring.encode(
          claims,
          typ: BaseApiAuthorityTokenProfileRegistry::TOKEN_TYPE,
          issuer_id: BaseApiAuthorityTokenProfileRegistry.key_issuer_id_for(profile),
        )
      end
    end
  end

  private

  attr_reader :rp_session, :profile, :audience_resource_type

  def record_class = profile.record_class

  def session_class = profile.session_class

  def valid_session?(session)
    return false unless session&.active?(now: record_class.database_now)

    binding = session.op_session_binding
    identity = binding&.identity_binding
    principal = identity&.principal
    return false unless valid_binding?(binding, identity, principal)
    return false unless matching_identity_context?(binding, identity)
    return false unless identity.subject.is_a?(String) && identity.subject.present?

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
end
