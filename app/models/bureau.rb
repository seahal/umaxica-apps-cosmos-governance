# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: bureaus
# Database name: org_zenith
#
#  id           :bigint           not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string           default(""), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string           default(""), not null
#
# Indexes
#
#  index_bureaus_on_public_id  (public_id) UNIQUE
#
class Bureau < OrgRpRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include ::Organization

  organization_interface_validations

  has_many :bureau_units, dependent: :destroy, inverse_of: :bureau
  has_many :agent_memberships, dependent: :restrict_with_error, inverse_of: :bureau
  has_one :ownership,
          class_name: "BureauOwnership",
          dependent: :restrict_with_error,
          inverse_of: :bureau
  has_one :lifecycle,
          class_name: "BureauLifecycle",
          dependent: :restrict_with_error,
          inverse_of: :bureau
  has_one :owner, through: :ownership, source: :operator
  has_many :administration_grants,
           class_name: "BureauAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :bureau
  has_many :delegation_grants,
           class_name: "BureauDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :bureau
  has_many :view_grants,
           class_name: "BureauViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :bureau
  has_many :ownership_transfer_requests,
           class_name: "BureauOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :bureau

  public
  def root_units
    bureau_units.where(parent_id: nil)
  end
end
