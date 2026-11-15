# typed: false
# frozen_string_literal: true

# One row per consumed Access-issued registration handoff. The unique jti digest is the replay
# barrier; the row is inserted in the same transaction as the state change it authorizes.
class ClientRegistrationHandoffReceipt < AppZenithRecord
  KINDS = %w(start credential cancellation).freeze

  validates :jti_digest, presence: true, length: { is: 64 }
  validates :jti_digest, uniqueness: true, on: :create
  validates :kind, presence: true, inclusion: { in: KINDS }, length: { maximum: 16 }
  validates :expires_at, presence: true

  class << self
    public

    # Consumes a handoff jti once inside the caller's transaction. Returns false when it was already
    # consumed (replay). ON CONFLICT DO NOTHING keeps a replay from aborting the transaction.
    def consume!(jti:, kind:, expires_at:)
      raise ArgumentError, "handoff receipt requires the app_zenith transaction" unless
        lease_connection.transaction_open?
      raise ArgumentError, "unsupported handoff kind" unless KINDS.include?(kind)

      inserted = insert(
        { jti_digest: Digest::SHA256.hexdigest(jti), kind:, expires_at:, created_at: database_now },
        unique_by: :jti_digest, returning: :id,
      )
      inserted.rows.any?
    end
  end

  public

  def readonly?
    persisted?
  end
end
