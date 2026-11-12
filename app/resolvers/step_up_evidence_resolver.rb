# frozen_string_literal: true

# Builds ordinary step-up evidence only from the already authenticated Base RP access state.
# Writers still recheck the evidence against their own live actor/session boundary.
class StepUpEvidenceResolver
  STEP_UP_ACR = "urn:umaxica:base:step-up".freeze

  class << self
    public

    def call(access_state:, actor:, cell:)
      new(access_state:, actor:, cell:).call
    end
  end

  public

  def initialize(access_state:, actor:, cell:)
    @access_state = access_state
    @actor = actor
    @cell = cell
  end

  def call
    record_class, session_class, principal_class, expected_actor, resource_type = boundary
    return unless valid_access_context?(expected_actor)

    return unless access_state.rp_session.is_a?(session_class)
    return unless access_state.resource.is_a?(principal_class)

    local_session_evidence(record_class:, session_class:, resource_type:)
  end

  private

  attr_reader :access_state, :actor, :cell

  def valid_access_context?(expected_actor)
    access_state.is_a?(BrowserRpAuthentication::AccessState) && access_state.status == :valid &&
      actor.is_a?(expected_actor) && actor.login_allowed? && !actor.deactivated? && access_state.payload.is_a?(Hash)
  end

  def local_session_evidence(record_class:, session_class:, resource_type:)
    record_class.connected_to(role: :writing) do
      session = session_class.includes(op_session_binding: { identity_binding: :principal })
        .find_by(id: access_state.rp_session.id, public_id: access_state.rp_session.public_id)
      next unless session

      verified_evidence(session:, resource_type:, now: record_class.database_now)
    end
  end

  def boundary
    case cell
    when RpCellBinding::Cell
      case cell.connection
      when "rp_base_app"
        [RpBaseAppRecord, RpBaseAppSession, RpBaseAppPrincipal, Client, "client"]
      when "rp_base_org"
        [RpBaseOrgRecord, RpBaseOrgSession, RpBaseOrgPrincipal, Operator, "operator"]
      else
        raise ArgumentError, "step-up evidence is supported only by Base RP cells"
      end
    else
      raise ArgumentError, "step-up evidence requires a registered RP cell"
    end
  end

  def verified_evidence(session:, resource_type:, now:)
    binding = session.op_session_binding
    identity = binding&.identity_binding
    return unless active_session_binding?(session:, binding:, identity:, now:)

    issuer = OidcIssuer.for_resource_type(resource_type)
    payload = access_state.payload
    return unless token_binding_matches?(payload:, binding:, identity:, issuer:, resource_type:)
    return unless authentication_evidence_valid?(payload:, now:)

    StepUpEvidenceValue.new(
      acr: payload.fetch("acr"), amr: payload.fetch("amr"), auth_time: payload.fetch("auth_time"),
      sid: payload.fetch("sid"), sub: payload.fetch("sub"), client_id: payload.fetch("client_id"),
      aud: payload.fetch("aud"), jti: payload.fetch("jti"),
    )
  end

  def active_session_binding?(session:, binding:, identity:, now:)
    session.revoked_at.nil? && session.absolute_expires_at.present? && session.absolute_expires_at > now &&
      binding && identity && binding.revoked_at.nil? && identity.principal.disabled_at.nil?
  end

  def token_binding_matches?(payload:, binding:, identity:, issuer:, resource_type:)
    subject = payload["sub"]
    exact?(payload["iss"], issuer) && exact?(identity.issuer, issuer) &&
      identity.realm == cell.realm && identity.client_id == cell.client_id &&
      identity.principal_id == access_state.resource.id && exact?(identity.subject, subject) &&
      exact?(binding.issuer, issuer) && exact?(binding.sid, payload["sid"]) &&
      exact?(OidcSubject.for(actor, resource_type:), subject) &&
      exact?(payload["client_id"], cell.client_id) && payload["aud"] == [OidcClientRegistry.find!(cell.client_id).aud]
  end

  def authentication_evidence_valid?(payload:, now:)
    auth_time = payload["auth_time"]
    authentication_context_permits_step_up?(payload) && exact?(payload["acr"], STEP_UP_ACR) &&
      payload["amr"].is_a?(Array) && payload["amr"].all? { |method| method.is_a?(String) && method.present? } &&
      auth_time.is_a?(Integer) && auth_time <= now.to_i && recent_authentication?(auth_time, now) &&
      payload["exp"].is_a?(Integer) && payload.fetch("exp") > now.to_i &&
      payload["jti"].is_a?(String) && payload["jti"].present?
  end

  def authentication_context_permits_step_up?(payload)
    context = payload[AuthenticationContextValue::CLAIM]
    return false unless AuthenticationContextValue::KEYS.include?(context)

    AuthenticationContextValue.for(context).step_up_permitted?
  end

  def recent_authentication?(auth_time, now)
    now.to_i < auth_time + StepUpEvidenceValue::MAX_AGE_SECONDS
  end

  def exact?(actual, expected)
    actual.is_a?(String) && expected.is_a?(String) && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end
end
