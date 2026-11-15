# typed: false
# frozen_string_literal: true

# H5 (user cancellation in Auth). Cancels only a pending, bound registration; never deletes anything
# (adr/sign-up-finalization-in-auth.md, "Cancellation (H5)").
class ClientRegistrationCancellationCommitter
  def self.call!(...)
    new(...).call!
  end
  public_class_method :call!

  def initialize(claims:, browser_secret_digest:)
    @claims = claims
    @browser_secret_digest = browser_secret_digest
  end

  public

  def call!
    AppZenithRecord.connected_to(role: :writing) do
      ClientRegistration.transaction { commit_cancellation }
    end
  end

  private

  attr_reader :claims, :browser_secret_digest

  def commit_cancellation
    return ClientRegistrationAnswerResult.new(reason: :replay) unless consume_receipt!

    registration = ClientRegistration.lock.find_by(public_id: claims.fetch("reg"))
    return refuse!("not_active", nil) unless registration
    return terminal_answer(registration) if registration.terminal?

    if registration.expired_at?(ClientRegistration.database_now)
      registration = ClientRegistrationTransitionWriter.expire!(registration)
      return ClientRegistrationAnswerResult.new(reason: "not_active", registration:)
    end
    return refuse!("conflict", registration) unless bound?(registration)

    registration = ClientRegistrationTransitionWriter.cancel!(registration)
    ClientRegistrationAnswerResult.new(reason: "cancelled", registration:)
  end

  def consume_receipt!
    ClientRegistrationHandoffReceipt.consume!(
      jti: claims.fetch("jti"), kind: "cancellation", expires_at: Time.zone.at(claims.fetch("exp")),
    )
  end

  def bound?(registration)
    registration.bound_to?(browser_secret_digest:, access_ceremony_digest: claims.fetch("cer"))
  end

  # Cancel never undoes a completed registration; the account stays and only its bound browser learns that.
  def terminal_answer(registration)
    if registration.completed? && bound?(registration)
      completion = ClientRegistrationCompletion.preload(:client).find_by!(sign_up_flow_ref: registration.public_id)
      return ClientRegistrationAnswerResult.new(reason: "completed", registration:, completion:)
    end

    refuse!("not_active", registration)
  end

  def refuse!(reason, registration)
    metadata = { handoff: "cancellation", reason: }
    metadata.merge!(registration_ref: registration.public_id, method: registration.method_key) if registration
    ClientRegistrationAuditOutbox.record!(
      event_type: "registration.refused", metadata:, occurred_at: ClientRegistration.database_now,
    )
    ClientRegistrationAnswerResult.new(reason:, registration:)
  end
end
