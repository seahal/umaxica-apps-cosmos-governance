# typed: false
# frozen_string_literal: true

class RpBaseAppConsumedIdTokenJti < RpBaseAppRecord
  self.table_name = "rp_consumed_id_token_jtis"

  validates :jti_digest, presence: true, length: { is: 64 }
  validates :jti_digest, format: { with: /\A[0-9a-f]{64}\z/ }, uniqueness: true
  validates :expires_at, presence: true
end
