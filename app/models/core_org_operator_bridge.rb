# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: core_org_operator_bridges
# Database name: org_zenith
#
#  id           :bigint           not null, primary key
#  audience     :string           default("umaxica-core-org"), not null
#  host         :string           default("jpx.umaxica.org"), not null
#  lock_version :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  operator_id  :bigint           not null
#  public_id    :string           default(""), not null
#  rp_client_id :string           default("core_org"), not null
#
# Indexes
#
#  idx_core_org_operator_bridges_unique_operator_rp  (operator_id,rp_client_id) UNIQUE
#  index_core_org_operator_bridges_on_public_id      (public_id) UNIQUE
#
class CoreOrgOperatorBridge < OrgRpRecord
  include CoreRpBridge
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_core_rp_defaults
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  class_attribute :core_default_client_id, instance_accessor: false
  class_attribute :core_default_audience, instance_accessor: false
  class_attribute :core_default_host, instance_accessor: false
  # rubocop:enable ThreadSafety/ClassAndModuleAttributes

  validates :rp_client_id, presence: true, length: { maximum: 64 }
  validates :audience, presence: true, length: { maximum: 128 }
  validates :host, presence: true, length: { maximum: 255 }

  belongs_to :operator,
             class_name: "Operator",
             inverse_of: :core_org_operator_bridges

  core_rp_bridge(
    actor_foreign_key: :operator_id,
    client_id: RpDeploymentBindingValue.client_id("core-org"),
    audience: "umaxica-core-org",
    host: "jpx.umaxica.org",
  )
end
