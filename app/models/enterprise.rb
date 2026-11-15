# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: enterprises
# Database name: app_zenith
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
#  index_enterprises_on_public_id  (public_id) UNIQUE
#
class Enterprise < AppRpRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include ::Organization

  organization_interface_validations

  has_many :enterprise_units, dependent: :destroy, inverse_of: :enterprise
  has_many :persona_memberships, dependent: :restrict_with_error, inverse_of: :enterprise
  has_one :ownership,
          class_name: "EnterpriseOwnership",
          dependent: :restrict_with_error,
          inverse_of: :enterprise
  has_one :lifecycle,
          class_name: "EnterpriseLifecycle",
          dependent: :restrict_with_error,
          inverse_of: :enterprise
  has_one :owner, through: :ownership, source: :client
  has_many :administration_grants,
           class_name: "EnterpriseAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :enterprise
  has_many :delegation_grants,
           class_name: "EnterpriseDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :enterprise
  has_many :view_grants,
           class_name: "EnterpriseViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :enterprise
  has_many :ownership_transfer_requests,
           class_name: "EnterpriseOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :enterprise

  public
  def root_units
    enterprise_units.where(parent_id: nil)
  end
end
