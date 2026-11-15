# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: operator_workspace_accounts
# Database name: org_zenith
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  moniker       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint
#  public_id     :string           not null
#  staff_id      :bigint           not null
#  status_id     :bigint           default(2), not null
#
# Indexes
#
#  index_operator_workspace_accounts_on_department_id  (department_id)
#  index_operator_workspace_accounts_on_public_id      (public_id) UNIQUE
#  index_operator_workspace_accounts_on_staff_id       (staff_id)
#  index_operator_workspace_accounts_on_status_id      (status_id)
#

class OperatorWorkspaceAccount < OrgRpRecord
  include Retainable

  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }
  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update
  Retainable.register_host(self)

  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  attribute :status_id, default: OperatorWorkspaceAccountStatus::NOTHING

  belongs_to :operator_workspace_account_status,
             foreign_key: :status_id,
             inverse_of: false
  belongs_to :operator,
             class_name: "Operator",
             foreign_key: :staff_id,
             inverse_of: false
  belongs_to :staff,
             class_name: "Operator",
             inverse_of: false
  belongs_to :department, inverse_of: :operator_workspace_accounts
  has_many :staff_operators, class_name: "OperatorWorkspaceAccountMembership", dependent: :destroy,
                             inverse_of: :operator_workspace_account
  has_many :operators,
           through: :staff_operators,
           source: :staff,
           disable_joins: true
end
