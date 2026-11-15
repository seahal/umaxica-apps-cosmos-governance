# typed: false
# frozen_string_literal: true

# H1 (registration start). One app_zenith transaction consumes the jti, decides eligibility, supersedes
# the pending registration of the same identifier or browser, creates the registration and, for a method
# without an Auth credential, completes it (adr/sign-up-finalization-in-auth.md, "Start (H1)").
class ClientRegistrationStartCommitter
  class MalformedIdentifier < StandardError; end

  PENDING_CLAIM_INDEXES = %w(
    index_client_registrations_pending_identifier index_client_registrations_pending_browser
  ).freeze
  ACTIVE_IDENTIFIER_INDEXES = %w(client_emails_effective_digest client_telephones_effective_digest).freeze

  def self.call!(...)
    new(...).call!
  end
  public_class_method :call!

  def initialize(claims:, browser_secret_digest:, new_browser_secret_digest:)
    @claims = claims
    @browser_secret_digest = browser_secret_digest
    @new_browser_secret_digest = new_browser_secret_digest
    @method_key = claims.fetch("mth")
    @method_id = ClientRegistrationCompletionMethod::IDS.fetch(@method_key)
    @normalized_identifier = normalize_identifier!
    @identifier_digest = digest_identifier
  end

  public

  def call!
    AppZenithRecord.connected_to(role: :writing) do
      ClientRegistration.transaction { commit_start }
    end
  rescue ActiveRecord::RecordNotUnique => e
    refuse_after_rollback(e)
  end

  private

  attr_reader :claims, :browser_secret_digest, :new_browser_secret_digest, :method_key, :method_id,
              :normalized_identifier, :identifier_digest

  def commit_start
    return ClientRegistrationAnswerResult.new(reason: :replay) unless consume_receipt!

    today = ClientRegistration.database_now.in_time_zone(Time.zone).to_date
    unless ClientRegistrationEligibilityPolicy.birthdate_eligible?(claims.fetch("bdt"), today:)
      return refuse!("ineligible")
    end
    return refuse!("sign_in_instead") if identifier_active?

    supersede_pending!
    registration = ClientRegistrationTransitionWriter.start!(
      method_id:, identifier_digest:, identifier: normalized_identifier, birthdate: claims.fetch("bdt"),
      access_ceremony_digest: claims.fetch("cer"), browser_secret_digest: new_browser_secret_digest,
    )
    return ClientRegistrationAnswerResult.new(reason: "started", registration:) if registration.credential_required?

    completion = ClientRegistrationAccountCreator.call!(registration:, credential: nil)
    registration = ClientRegistrationTransitionWriter.complete!(registration)
    ClientRegistrationAnswerResult.new(reason: "completed", registration:, completion:)
  end

  def consume_receipt!
    ClientRegistrationHandoffReceipt.consume!(
      jti: claims.fetch("jti"), kind: "start", expires_at: Time.zone.at(claims.fetch("exp")),
    )
  end

  def identifier_active?
    case method_key
    when "email" then ClientEmail.effective_binding.exists?(address_digest: identifier_digest)
    when "telephone" then ClientTelephone.effective_binding.exists?(number_digest: identifier_digest)
    else raise ArgumentError, "unsupported registration method #{method_key.inspect}"
    end
  end

  def supersede_pending!
    pending = ClientRegistration.lock.where(status_id: ClientRegistrationStatus::CREDENTIAL_PENDING)
    by_identifier = pending.where(method_id:, identifier_digest:).to_a
    by_browser = browser_secret_digest ? pending.where(browser_secret_digest:).to_a : []
    by_identifier.each do |registration|
      ClientRegistrationTransitionWriter.halt!(registration, reason: "superseded_by_identifier")
    end
    (by_browser - by_identifier).each do |registration|
      ClientRegistrationTransitionWriter.halt!(registration, reason: "superseded_in_browser")
    end
  end

  def refuse!(reason)
    ClientRegistrationAuditOutbox.record!(
      event_type: "registration.refused", metadata: { method: method_key, handoff: "start", reason: },
      occurred_at: ClientRegistration.database_now,
    )
    ClientRegistrationAnswerResult.new(reason:)
  end

  # A unique index refused the commit after a concurrent writer won. The jti is consumed and the refusal
  # recorded in a second transaction; nothing else from the first transaction survives.
  def refuse_after_rollback(error)
    constraint = unique_constraint_name(error)
    reason =
      if PENDING_CLAIM_INDEXES.include?(constraint)
        "conflict"
      elsif ACTIVE_IDENTIFIER_INDEXES.include?(constraint)
        "sign_in_instead"
      else
        raise error
      end
    AppZenithRecord.connected_to(role: :writing) do
      ClientRegistration.transaction do
        next ClientRegistrationAnswerResult.new(reason: :replay) unless consume_receipt!

        refuse!(reason)
      end
    end
  end

  def unique_constraint_name(error)
    cause = error.cause
    cause.is_a?(PG::UniqueViolation) ? cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) : nil
  end

  def normalize_identifier!
    normalized =
      case method_key
      when "email" then IdentifierBlindIndex.normalize_email(claims.fetch("idf"))
      when "telephone" then IdentifierBlindIndex.normalize_telephone(claims.fetch("idf"))
      else raise ArgumentError, "unsupported registration method #{method_key.inspect}"
      end
    raise MalformedIdentifier, "registration identifier cannot be normalized" if normalized.blank?

    normalized
  end

  def digest_identifier
    case method_key
    when "email" then IdentifierBlindIndex.bidx_for_email(normalized_identifier, realm: "app")
    when "telephone" then IdentifierBlindIndex.bidx_for_telephone(normalized_identifier, realm: "app")
    else raise ArgumentError, "unsupported registration method #{method_key.inspect}"
    end
  end
end
