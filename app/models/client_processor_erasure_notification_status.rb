# typed: false
# frozen_string_literal: true

class ClientProcessorErasureNotificationStatus < AppPrincipalRecord
  include ReferenceRecord

  has_many :client_processor_erasure_notifications, foreign_key: :status_id, inverse_of: :status,
                                                    dependent: :restrict_with_error

  PENDING = 10
  NOTIFIED = 20
  RETRYABLE_FAILURE = 30
  SKIPPED = 40
  PERMANENT_FAILURE = 50
  DEFAULTS = [PENDING, NOTIFIED, RETRYABLE_FAILURE, SKIPPED, PERMANENT_FAILURE].freeze

  self.record_timestamps = false
end
