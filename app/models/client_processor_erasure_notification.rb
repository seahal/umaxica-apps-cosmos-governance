# typed: false
# frozen_string_literal: true

class ClientProcessorErasureNotification < AppPrincipalRecord
  include ProcessorErasureNotificationState
  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_processor_notification_defaults, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include Retainable

  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }
  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update
  Retainable.register_host(self)

  validates :processor_key, inclusion: { in: PROCESSOR_KEYS }
  validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
  validates :requested_at, presence: true
  validates :delivery_generation, numericality: { only_integer: true, greater_than: 0 }
  validates :delivery_idempotency_key_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :pending_for_processing,
        lambda { |now = nil|
          now ||= database_now
          where(status_id: [status_id_for("PENDING"), status_id_for("RETRYABLE_FAILURE")])
            .where(arel_table[:next_retry_at].eq(nil).or(arel_table[:next_retry_at].lteq(now)))
        }

  STATUS_MODEL = ClientProcessorErasureNotificationStatus
  STATUSES = {
    "PENDING" => STATUS_MODEL::PENDING,
    "NOTIFIED" => STATUS_MODEL::NOTIFIED,
    "RETRYABLE_FAILURE" => STATUS_MODEL::RETRYABLE_FAILURE,
    "SKIPPED" => STATUS_MODEL::SKIPPED,
    "PERMANENT_FAILURE" => STATUS_MODEL::PERMANENT_FAILURE,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client_privacy_request, inverse_of: :client_processor_erasure_notifications
  belongs_to :status, class_name: "ClientProcessorErasureNotificationStatus",
                      inverse_of: :client_processor_erasure_notifications
  has_many :attempts,
           class_name: "ClientProcessorErasureNotificationAttempt",
           inverse_of: :notification,
           dependent: :delete_all

  validates :processor_key, uniqueness: { scope: :client_privacy_request_id }
  validates :delivery_idempotency_key_digest, length: { maximum: 64 }
  validates :delivery_idempotency_key_digest, exclusion: { in: [nil] }
end
