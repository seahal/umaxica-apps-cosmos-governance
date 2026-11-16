# typed: false
# frozen_string_literal: true

# Lifecycle states of a Governance-owned pending registration. Rows are seeded by migration.
class ClientRegistrationStatus < AppZenithRecord
  CREDENTIAL_PENDING = 1
  COMPLETED = 2
  CANCELLED = 3
  EXPIRED = 4
  HALTED = 5
  IDS = [CREDENTIAL_PENDING, COMPLETED, CANCELLED, EXPIRED, HALTED].freeze
  TERMINAL_IDS = [COMPLETED, CANCELLED, EXPIRED, HALTED].freeze

  self.record_timestamps = false

  has_many :registrations, class_name: "ClientRegistration", foreign_key: :status_id,
                           inverse_of: :status, dependent: :restrict_with_exception

  validates :id, inclusion: { in: IDS }

  public

  def readonly?
    persisted?
  end
end
