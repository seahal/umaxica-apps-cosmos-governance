# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: personas
# Database name: app_zenith
#
# The physical table remains `personas` for the naming migration. The concrete
# Ruby model is ClientPersona; Persona is the common interface concern.
class ClientPersona < AppRpRecord
  self.table_name = "personas"

  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include ::Persona

  persona_interface_validations

  belongs_to :client_identity, inverse_of: :client_persona
  has_many :persona_assignments, dependent: :destroy, inverse_of: :persona
  has_many :persona_memberships, dependent: :destroy, inverse_of: :persona
  has_one :ownership,
          class_name: "ClientPersonaOwnership",
          dependent: :restrict_with_error,
          inverse_of: :client_persona
  has_one :lifecycle,
          class_name: "ClientPersonaLifecycle",
          dependent: :restrict_with_error,
          inverse_of: :client_persona
  has_one :owner, through: :ownership, source: :client
  has_many :administration_grants,
           class_name: "ClientPersonaAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :delegation_grants,
           class_name: "ClientPersonaDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :usage_grants,
           class_name: "ClientPersonaUsageGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :view_grants,
           class_name: "ClientPersonaViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :ownership_transfer_requests,
           class_name: "ClientPersonaOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_one :avatar_persona_binding,
          class_name: "AvatarPersonaBinding",
          dependent: :destroy,
          inverse_of: :persona

  validates :client_identity_id, uniqueness: true

  public

  def current_avatar_persona_binding
    return nil unless persisted?

    AvatarPersonaBinding.active.find_by(persona_id: id)
  end

  def current_avatar
    binding = current_avatar_persona_binding
    Avatar.find_by(id: binding&.avatar_id)
  end
end
