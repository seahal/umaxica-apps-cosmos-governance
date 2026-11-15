# typed: false
# frozen_string_literal: true

class EnterpriseOwnershipTransferRequest < AppRpRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  PENDING = "pending"
  STATUSES = %w(pending accepted rejected cancelled expired invalidated).freeze
  LIFETIME = 24.hours

  belongs_to :enterprise, inverse_of: :ownership_transfer_requests
  belongs_to :source_client, class_name: "Client",
                             inverse_of: :outgoing_enterprise_ownership_transfer_requests
  belongs_to :destination_client, class_name: "Client",
                                  inverse_of: :incoming_enterprise_ownership_transfer_requests

  validates :enterprise_id,
            uniqueness: { conditions: -> { where(status: PENDING) } },
            on: :create, if: -> { status == PENDING }

  validates :requested_at, :expires_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :expected_ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parties_must_differ
  validate :expiry_must_follow_request

  scope :pending, -> { where(status: PENDING) }
  scope :due, ->(now = Time.current) { pending.where(expires_at: ..now) }

  private

  def parties_must_differ
    return if source_client_id.blank? || destination_client_id.blank?
    return unless source_client_id == destination_client_id

    errors.add(:destination_client_id, "must differ from source_client_id")
  end

  def expiry_must_follow_request
    return if requested_at.blank? || expires_at.blank?
    return if requested_at < expires_at

    errors.add(:expires_at, "must be after requested_at")
  end
end
