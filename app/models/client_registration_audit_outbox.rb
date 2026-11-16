# typed: false
# frozen_string_literal: true

# Same-transaction audit source for registration lifecycle facts. ClientRegistrationAuditDeliveryJob
# copies each row into Chronicle and then marks it delivered.
class ClientRegistrationAuditOutbox < AppZenithRecord
  EVENT_TYPES = %w(
    registration.started registration.completed registration.cancelled
    registration.expired registration.halted registration.refused
  ).freeze
  METADATA_KEYS = %w(registration_ref method handoff reason).freeze

  attr_readonly :event_uuid, :event_type, :metadata, :occurred_at

  validates :event_uuid, presence: true
  validates :event_uuid, uniqueness: true, on: :create
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }, length: { maximum: 32 }
  validates :occurred_at, presence: true
  validates :delivered, inclusion: { in: [true, false] }
  validate :metadata_has_only_references

  class << self
    public

    def record!(event_type:, metadata:, occurred_at:)
      raise ArgumentError, "registration audit requires the app_zenith transaction" unless
        lease_connection.transaction_open?

      create!(event_uuid: SecureRandom.uuid, event_type:, metadata: metadata.stringify_keys, occurred_at:)
    end
  end

  private

  # The identifier, birthdate, credential material, tokens and cookies never enter an audit event.
  def metadata_has_only_references
    unless metadata.is_a?(Hash) && (metadata.keys - METADATA_KEYS).empty? &&
        metadata.values.all? { |value| value.is_a?(String) }
      errors.add(:metadata, :invalid)
    end
  end
end
