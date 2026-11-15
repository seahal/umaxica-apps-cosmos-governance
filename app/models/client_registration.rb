# typed: false
# frozen_string_literal: true

# Governance-owned pending registration (adr/sign-up-finalization-in-auth.md, Cosmos split amendment).
# Initial rows are built by ClientRegistrationTransitionWriter#start!; every later status change goes
# through that writer. No account row exists for a registration until it completes.
class ClientRegistration < AppZenithRecord
  LIFETIME = 30.minutes
  RETENTION = 7.days
  # Accepted requirement sets (owner item O-4): only telephone registers an Auth credential (a passkey)
  # before completion; email completes at the start handoff.
  CREDENTIAL_REQUIRED_METHODS = %w(telephone).freeze

  encrypts :identifier
  encrypts :birthdate

  attr_readonly :public_id, :method_id, :identifier_digest, :identifier, :birthdate, :webauthn_user_handle,
                :access_ceremony_digest, :browser_secret_digest, :deadline_at

  belongs_to :status, class_name: "ClientRegistrationStatus", inverse_of: :registrations
  belongs_to :completion_method, class_name: "ClientRegistrationCompletionMethod", foreign_key: :method_id,
                                 inverse_of: false

  validates :public_id, presence: true, length: { is: 21 }
  validates :public_id, uniqueness: true, on: :create
  validates :webauthn_user_handle, presence: true, length: { is: 43 }
  validates :webauthn_user_handle, uniqueness: true, on: :create
  validates :identifier_digest, presence: true, length: { is: 64 }
  validates :identifier_digest,
            uniqueness: { scope: :method_id,
                          conditions: -> { where(status_id: ClientRegistrationStatus::CREDENTIAL_PENDING) }, },
            if: :pending?
  validates :access_ceremony_digest, presence: true, length: { is: 43 }
  validates :browser_secret_digest, presence: true, length: { is: 64 }
  validates :browser_secret_digest,
            uniqueness: { conditions: -> { where(status_id: ClientRegistrationStatus::CREDENTIAL_PENDING) } },
            if: :pending?
  validates :identifier, :birthdate, :deadline_at, :status_changed_at, :purge_after, presence: true
  validates :status_id, inclusion: { in: ClientRegistrationStatus::IDS }
  validates :method_id, inclusion: { in: ClientRegistrationCompletionMethod::IDS.values }

  public

  def pending?
    status_id == ClientRegistrationStatus::CREDENTIAL_PENDING
  end

  def completed?
    status_id == ClientRegistrationStatus::COMPLETED
  end

  def terminal?
    ClientRegistrationStatus::TERMINAL_IDS.include?(status_id)
  end

  # The deadline itself is already expired: a credential arriving at deadline_at is too late.
  def expired_at?(now)
    deadline_at <= now
  end

  def purgeable_at?(now)
    terminal? && purge_after <= now
  end

  def credential_required?
    CREDENTIAL_REQUIRED_METHODS.include?(method_key)
  end

  def method_key
    ClientRegistrationCompletionMethod::IDS.key(method_id) ||
      raise(ArgumentError, "registration method #{method_id.inspect} is not registered")
  end

  # Both browser bindings must match: Governance's cookie secret and Access's ceremony reference.
  def bound_to?(browser_secret_digest:, access_ceremony_digest:)
    secure_equal?(self.browser_secret_digest, browser_secret_digest) &&
      secure_equal?(self.access_ceremony_digest, access_ceremony_digest)
  end

  private

  def secure_equal?(stored, presented)
    presented.is_a?(String) && stored.bytesize == presented.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(stored, presented)
  end
end
