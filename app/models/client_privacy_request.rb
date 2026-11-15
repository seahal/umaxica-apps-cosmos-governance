# typed: false
# frozen_string_literal: true

class ClientPrivacyRequest < AppPrincipalRecord
  include PrivacyRequestState
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_privacy_request_defaults, on: :create
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

  validates :request_kind, inclusion: { in: REQUEST_KINDS }
  validates :jurisdiction, inclusion: { in: JURISDICTIONS }
  validates :request_source, inclusion: { in: REQUEST_SOURCES }
  validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
  validates :received_at, :response_due_at, presence: true

  scope :open_for_recovery_block,
        -> {
          where(
            status_id: status_ids_for(
              "VERIFIED", "PROCESSING", "COMPLETED", "BLOCKED_BY_LEGAL_HOLD",
              "PARTIALLY_DENIED",
            ),
          )
        }
  scope :open_for_hold_block,
        -> { where(status_id: status_ids_for("RECEIVED", "VERIFICATION_REQUIRED", "VERIFIED", "PROCESSING")) }
  scope :received, -> { where(status_id: status_id_for("RECEIVED")) }

  STATUS_MODEL = ClientPrivacyRequestStatus
  STATUSES = {
    "RECEIVED" => STATUS_MODEL::RECEIVED,
    "VERIFICATION_REQUIRED" => STATUS_MODEL::VERIFICATION_REQUIRED,
    "VERIFIED" => STATUS_MODEL::VERIFIED,
    "PROCESSING" => STATUS_MODEL::PROCESSING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "PARTIALLY_DENIED" => STATUS_MODEL::PARTIALLY_DENIED,
    "BLOCKED_BY_LEGAL_HOLD" => STATUS_MODEL::BLOCKED_BY_LEGAL_HOLD,
    "CANCELLED" => STATUS_MODEL::CANCELLED,
    "FAILED" => STATUS_MODEL::FAILED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client, inverse_of: :client_privacy_requests
  belongs_to :status, class_name: "ClientPrivacyRequestStatus", inverse_of: :client_privacy_requests
  has_many :client_processor_erasure_notifications, dependent: :delete_all, inverse_of: :client_privacy_request
end
