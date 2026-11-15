# typed: false
# frozen_string_literal: true

# The only writer of ClientRegistration lifecycle state (.agents/harnesses/rules/generic/lifecycle-transition-
# writers.mdc; docs/mermaid/app-pending-registration-transition-inventory.md). Every edge runs inside the
# caller's app_zenith transaction, locks and reloads the row, reads the app_zenith clock itself, rechecks
# the source state and deadline, and writes its Chronicle outbox row in the same transaction.
class ClientRegistrationTransitionWriter
  class Refused < StandardError; end

  HALT_REASONS = %w(superseded_by_identifier superseded_in_browser identifier_taken integrity_violation).freeze

  class << self
    public

    # Initial row construction: event `start`.
    def start!(method_id:, identifier_digest:, identifier:, birthdate:, access_ceremony_digest:,
               browser_secret_digest:)
      require_transaction!
      now = ClientRegistration.database_now
      registration = ClientRegistration.create!(
        public_id: PublicId.generate, status_id: ClientRegistrationStatus::CREDENTIAL_PENDING,
        method_id:, identifier_digest:, identifier:, birthdate:,
        webauthn_user_handle: SecureRandom.urlsafe_base64(WebauthnUserHandleOwner::USER_HANDLE_RANDOM_BYTES),
        access_ceremony_digest:, browser_secret_digest:,
        deadline_at: now + ClientRegistration::LIFETIME, status_changed_at: now,
        purge_after: now + ClientRegistration::LIFETIME + ClientRegistration::RETENTION,
      )
      record!("registration.started", registration, now)
      registration
    end

    def complete!(registration)
      transition!(registration, ClientRegistrationStatus::COMPLETED, "registration.completed")
    end

    def cancel!(registration)
      transition!(registration, ClientRegistrationStatus::CANCELLED, "registration.cancelled")
    end

    def expire!(registration)
      transition!(registration, ClientRegistrationStatus::EXPIRED, "registration.expired")
    end

    def halt!(registration, reason:)
      raise ArgumentError, "unsupported registration halt reason" unless HALT_REASONS.include?(reason)

      transition!(registration, ClientRegistrationStatus::HALTED, "registration.halted", reason:)
    end

    private

    def transition!(registration, to_status_id, event_type, reason: nil)
      require_transaction!
      locked = ClientRegistration.lock.find(registration.id)
      now = ClientRegistration.database_now
      raise Refused, "registration #{locked.public_id} is terminal" unless locked.pending?

      expired = locked.expired_at?(now)
      if to_status_id == ClientRegistrationStatus::EXPIRED
        raise Refused, "registration #{locked.public_id} has not reached its deadline" unless expired
      elsif expired
        raise Refused, "registration #{locked.public_id} passed its deadline"
      end

      locked.update!(status_id: to_status_id, status_changed_at: now, purge_after: now + ClientRegistration::RETENTION)
      record!(event_type, locked, now, reason:)
      locked
    end

    def record!(event_type, registration, now, reason: nil)
      metadata = { registration_ref: registration.public_id, method: registration.method_key }
      metadata[:reason] = reason if reason
      ClientRegistrationAuditOutbox.record!(event_type:, metadata:, occurred_at: now)
    end

    def require_transaction!
      return if ClientRegistration.lease_connection.transaction_open?

      raise ArgumentError, "registration transitions require the app_zenith transaction"
    end
  end
end
