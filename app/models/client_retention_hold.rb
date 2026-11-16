# typed: false
# frozen_string_literal: true

class ClientRetentionHold < AppPrincipalRecord
  include RetentionHoldState
  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_retention_hold_defaults, on: :create
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

  validates :hold_kind, inclusion: { in: HOLD_KINDS }
  validates :reason_code, inclusion: { in: REASON_CODES }
  validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
  validates :applied_at, presence: true

  scope :active_at,
        lambda { |now = Time.current|
          where(status_id: status_id_for("ACTIVE"))
            .where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(now)))
        }

  STATUS_MODEL = ClientRetentionHoldStatus
  STATUSES = {
    "ACTIVE" => STATUS_MODEL::ACTIVE,
    "RELEASED" => STATUS_MODEL::RELEASED,
    "EXPIRED" => STATUS_MODEL::EXPIRED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client, inverse_of: :client_retention_holds
  belongs_to :status, class_name: "ClientRetentionHoldStatus", inverse_of: :client_retention_holds
end
