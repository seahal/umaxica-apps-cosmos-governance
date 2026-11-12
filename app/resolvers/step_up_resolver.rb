# typed: false
# frozen_string_literal: true

class StepUpResolver
  DEFAULT_TTL = StepUpRequirement::DEFAULT_TTL
  # Consolidation ADR 2.3: the longest Step-Up validity and the accepted methods per Security Mode.
  NORMAL_MAXIMUM_TTL = 15.minutes
  ADVANCED_MAXIMUM_TTL = 5.minutes
  ADVANCED_METHODS = %w(passkey).freeze

  def self.call(token:, requirement: nil, scope: nil, allowed_methods: nil,
                session_binding: nil, token_binding: nil, now: Time.current, ttl: DEFAULT_TTL,
                require_session_binding: true, phishing_resistant_required: false,
                user_verification_required: false, full_reauthentication_required: false,
                purpose: "step_up", audience: "step_up:resolver", actor_ref: "resolver",
                resource_ref: nil, tenant_ref: nil, step_up_required: true,
                # @deprecated Legacy AAL demands are refused and never authorize a result.
                required_aal: nil)
    unless required_aal.blank? || required_aal.to_s == StepUpRequirement::NO_AAL
      raise StepUpRequirement::Invalid, "legacy AAL requirements are unsupported"
    end

    raise AccessOpDataUnavailableError if token.present?

    requirement ||= StepUpRequirement.new(
      step_up_required: step_up_required,
      scope: scope,
      allowed_methods: allowed_methods || StepUpRequirement::DEFAULT_ALLOWED_METHODS,
      phishing_resistant_required: phishing_resistant_required,
      user_verification_required: user_verification_required,
      full_reauthentication_required: full_reauthentication_required,
      session_binding: session_binding || token&.public_id,
      token_binding: token_binding || token&.public_id,
      ttl: ttl,
      purpose: purpose,
      audience: audience,
      require_session_binding: require_session_binding,
      actor_ref: actor_ref,
      resource_ref: resource_ref,
      tenant_ref: tenant_ref,
    )
    requirement = StepUpRequirement.build(requirement)
    new(token: token, requirement: requirement, now: now).call
  end

  def initialize(token:, requirement:, now:)
    @token = token
    @requirement = requirement
    @now = now
  end

  def call
    raise AccessOpDataUnavailableError if token.present?

    Actor::StepUp.new(
      scope: requirement.scope,
      required_aal: nil,
      allowed_methods: requirement.allowed_methods,
      satisfied: !requirement.step_up_required?,
      satisfied_at: nil,
      expires_at: nil,
      usable_token: false,
      method: nil,
      session_bound: !requirement.require_session_binding && requirement.session_binding.blank?,
      token_bound: false,
      purpose: requirement.purpose,
      audience: requirement.audience,
      purpose_bound: requirement.purpose.blank?,
      audience_bound: requirement.audience.blank?,
      phishing_resistant_required: requirement.phishing_resistant_required?,
      user_verification_required: requirement.user_verification_required?,
      full_reauthentication_required: requirement.full_reauthentication_required?,
      resource_bound: requirement.resource_ref.blank?,
      tenant_bound: requirement.tenant_ref.blank?,
    )
  end

  private

  attr_reader :token, :requirement
end
