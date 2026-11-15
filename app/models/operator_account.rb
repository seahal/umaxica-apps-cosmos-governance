# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_accounts
# Database name: org_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_accounts_on_public_id  (public_id) UNIQUE
#  index_operator_accounts_on_staff_id   (staff_id) UNIQUE
#
class OperatorAccount < OrgRpRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  belongs_to :staff, inverse_of: :rp_account, class_name: "Operator"

  validates :staff_id, uniqueness: true
end
