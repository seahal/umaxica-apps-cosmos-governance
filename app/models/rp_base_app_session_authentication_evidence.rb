# typed: false
# frozen_string_literal: true

class RpBaseAppSessionAuthenticationEvidence < RpBaseAppRecord
  self.table_name = "rp_session_authentication_evidences"

  belongs_to :rp_session, class_name: "RpBaseAppSession", inverse_of: :authentication_evidence

  validates :acr, presence: true, length: { maximum: 255 }
  validates :amr, presence: true
  validates :auth_time, numericality: { only_integer: true, greater_than: 0 }
  validates :rp_session_id, uniqueness: true
  validates :id_token_jti_digest, presence: true, length: { is: 64 }, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :authentication_context,
            inclusion: { in: [AuthenticationContextValue::NORMAL_KEY] }, length: { maximum: 16 }
  validate :amr_contains_nonblank_methods

  private

  def amr_contains_nonblank_methods
    return if amr.is_a?(Array) && amr.present? && amr.all? { |method| method.is_a?(String) && method.present? }

    errors.add(:amr, "must be a nonempty array of nonblank methods")
  end
end
