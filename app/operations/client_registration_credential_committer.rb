# typed: false
# frozen_string_literal: true

# H3 (credential delivery). One app_zenith transaction consumes the jti, checks the pending registration
# under its row lock and creates the account (adr/sign-up-finalization-in-auth.md, "Credential
# registration and completion (H3)").
class ClientRegistrationCredentialCommitter
  IDENTIFIER_INDEXES = %w(client_emails_effective_digest client_telephones_effective_digest).freeze
  CREDENTIAL_INDEXES = %w(index_client_passkeys_on_webauthn_id).freeze

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
      ClientRegistration.transaction { commit_credential }
    end
  rescue ActiveRecord::RecordNotUnique => e
    refuse_after_rollback(e)
  end

  private

  attr_reader :claims, :browser_secret_digest

  def commit_credential
    return ClientRegistrationAnswerResult.new(reason: :replay) unless consume_receipt!

    registration = ClientRegistration.lock.find_by(public_id: claims.fetch("reg"))
    return refuse!("conflict", nil) unless registration
    return terminal_answer(registration) if registration.terminal?

    if registration.expired_at?(ClientRegistration.database_now)
      registration = ClientRegistrationTransitionWriter.expire!(registration)
      return ClientRegistrationAnswerResult.new(reason: "not_active", registration:)
    end
    return refuse!("conflict", registration) unless bound?(registration)
    return refuse!("conflict", registration) unless claims.fetch("mth") == registration.method_key &&
      registration.credential_required?
    return refuse!("credential_rejected", registration) if ClientPasskey.exists?(webauthn_id: claims.fetch("cid"))

    if identifier_active?(registration)
      registration = ClientRegistrationTransitionWriter.halt!(registration, reason: "identifier_taken")
      return ClientRegistrationAnswerResult.new(reason: "sign_in_instead", registration:)
    end

    completion = ClientRegistrationAccountCreator.call!(registration:, credential:)
    registration = ClientRegistrationTransitionWriter.complete!(registration)
    ClientRegistrationAnswerResult.new(reason: "completed", registration:, completion:)
  end

  def consume_receipt!
    ClientRegistrationHandoffReceipt.consume!(
      jti: claims.fetch("jti"), kind: "credential", expires_at: Time.zone.at(claims.fetch("exp")),
    )
  end

  def bound?(registration)
    registration.bound_to?(browser_secret_digest:, access_ceremony_digest: claims.fetch("cer"))
  end

  # A completed registration is revealed only to its own bound browser and ceremony.
  def terminal_answer(registration)
    if registration.completed? && bound?(registration)
      completion = ClientRegistrationCompletion.preload(:client).find_by!(sign_up_flow_ref: registration.public_id)
      return ClientRegistrationAnswerResult.new(reason: "completed", registration:, completion:)
    end

    refuse!("not_active", registration)
  end

  def identifier_active?(registration)
    case registration.method_key
    when "telephone" then ClientTelephone.effective_binding.exists?(number_digest: registration.identifier_digest)
    when "email" then ClientEmail.effective_binding.exists?(address_digest: registration.identifier_digest)
    else raise ArgumentError, "unsupported registration method #{registration.method_key.inspect}"
    end
  end

  def credential
    ClientRegistrationAccountCreator::Credential.new(
      credential_id: claims.fetch("cid"), public_key: claims.fetch("cpk"), sign_count: claims.fetch("cnt"),
      backup_eligible: claims.fetch("be"), backed_up: claims.fetch("bs"),
    )
  end

  def refuse!(reason, registration)
    metadata = { handoff: "credential", reason: }
    metadata.merge!(registration_ref: registration.public_id, method: registration.method_key) if registration
    ClientRegistrationAuditOutbox.record!(
      event_type: "registration.refused", metadata:, occurred_at: ClientRegistration.database_now,
    )
    ClientRegistrationAnswerResult.new(reason:, registration:)
  end

  # The first transaction rolled back. A second one consumes the jti and records the outcome the ADR
  # assigns to the refusing index: identifier_taken halts the registration, a credential conflict
  # leaves it pending.
  def refuse_after_rollback(error)
    cause = error.cause
    constraint = cause.is_a?(PG::UniqueViolation) ? cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) : nil
    raise error unless IDENTIFIER_INDEXES.include?(constraint) || CREDENTIAL_INDEXES.include?(constraint)

    AppZenithRecord.connected_to(role: :writing) do
      ClientRegistration.transaction do
        next ClientRegistrationAnswerResult.new(reason: :replay) unless consume_receipt!

        registration = ClientRegistration.lock.find_by!(public_id: claims.fetch("reg"))
        next terminal_answer(registration) if registration.terminal?
        next refuse!("credential_rejected", registration) if CREDENTIAL_INDEXES.include?(constraint)

        registration = ClientRegistrationTransitionWriter.halt!(registration, reason: "identifier_taken")
        ClientRegistrationAnswerResult.new(reason: "sign_in_instead", registration:)
      end
    end
  end
end
