# typed: false
# frozen_string_literal: true

class AvatarPurgeDeferral < AvatarRecord
  belongs_to :avatar, inverse_of: :purge_deferrals

  validates :reason_code, presence: true
  validates :reason_code, uniqueness: { scope: :avatar_id }
  validates :attempt_count, numericality: { only_integer: true, greater_than: 0 }
  validates :reason_code, length: { maximum: 100 }
  validates :first_observed_at, exclusion: { in: [nil] }

  public

  # Record one observable, idempotent deferral for the Avatar and reason.
  # Lock the Avatar before looking up a deferral, matching the retention writer's lock order.
  # This also serializes first creation, before uniqueness validation can observe a competing row.
  def self.record!(avatar:, reason_code:, observed_at: Avatar.database_now)
    transaction do
      Avatar.lock.find(avatar.id)
      row =
        find_or_create_by!(avatar_id: avatar.id, reason_code: reason_code) do |candidate|
          candidate.attempt_count = 1
          candidate.first_observed_at = observed_at
          candidate.last_observed_at = observed_at
        end
      next row if row.previously_new_record?

      row.with_lock do
        row.update!(
          attempt_count: row.attempt_count + 1,
          last_observed_at: observed_at,
        )
      end
      row
    end
  end

  public_class_method :record!
end
