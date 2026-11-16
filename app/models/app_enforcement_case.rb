# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: Enforcement Case for the app realm (Client).
class AppEnforcementCase < AppPrincipalRecord
  include EnforcementCaseApplicable

  validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
  validates :kind, presence: true, inclusion: { in: EnforcementCaseApplicable::KINDS }
  validates :state, presence: true, inclusion: { in: EnforcementCaseApplicable::STATES }
  validates :duration_mode, presence: true, inclusion: { in: EnforcementCaseApplicable::DURATION_MODES }
  validates :visibility, presence: true, inclusion: { in: EnforcementCaseApplicable::VISIBILITIES }
  validates :release_mode, presence: true, inclusion: { in: EnforcementCaseApplicable::RELEASE_MODES }
  validates :end_reason, inclusion: { in: EnforcementCaseApplicable::END_REASONS }, allow_nil: true
  validates :reason_code, presence: true, inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES }
  validates :principal_public_id, presence: true
  validates :applied_by_operator_public_id, presence: true
  validates :effective_at, presence: true
  validate :public_id_immutable_after_create, on: :update

  before_validation :assign_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :assign_public_id
  around_create :retry_generated_public_id_collision

  encrypts :reason_note

  self.table_name = "app_enforcement_cases"

  # `validate: true` so an invalid effect fails the Case save; a has_one otherwise drops it silently
  # and the Case would go active without the effect it was applied for.
  has_one :principal_effect, class_name: "AppEnforcementPrincipalEffect", dependent: :destroy,
                             inverse_of: :enforcement_case, validate: true
  has_many :authentication_method_effects, class_name: "AppEnforcementAuthenticationMethodEffect",
                                           dependent: :destroy,
                                           inverse_of: :enforcement_case
  has_many :identifier_effects, class_name: "AppEnforcementIdentifierEffect", dependent: :destroy,
                                inverse_of: :enforcement_case
  has_many :principal_links, class_name: "AppEnforcementPrincipalLink", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_one :appeal, class_name: "AppEnforcementAppeal", dependent: :destroy, inverse_of: :enforcement_case

  def self.principal_class
    ::Client
  end
  public_class_method :principal_class

  def self.realm
    "app"
  end
  public_class_method :realm
  public

  def principal_effect_record
    AppEnforcementPrincipalEffect.find_by(app_enforcement_case_id: id)
  end
end
