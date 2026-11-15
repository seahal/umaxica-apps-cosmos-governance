# typed: false
# frozen_string_literal: true

class OrgEnforcementAppeal < OrgPrincipalRecord
  validates :org_enforcement_case_id, uniqueness: true

  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include EnforcementAppeal

  encrypts :statement

  validates :state, presence: true, inclusion: { in: EnforcementAppeal::STATES }
  validates :reason_code, presence: true, inclusion: { in: EnforcementAppeal::REASON_CODES }
  validates :statement, presence: true, length: { maximum: EnforcementAppeal::MAXIMUM_STATEMENT_LENGTH },
                        unless: :redacted?
  validates :submitted_at, presence: true
  validates :resolution_code, inclusion: { in: EnforcementAppeal::RESOLUTION_CODES }, allow_nil: true
  validate :reviewer_is_separate_from_case_operators, if: :reviewer_operator_public_id?

  belongs_to :enforcement_case, class_name: "OrgEnforcementCase", foreign_key: :org_enforcement_case_id,
                                inverse_of: :appeal
end
