# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
# Database name: app_zenith
#
#  id                          :bigint           not null, primary key
#  access_state                :string           default("enabled"), not null
#  admin_locked_at             :datetime
#  admin_locked_reason_code    :string
#  admin_locked_reason_note    :text
#  birthdate                   :text
#  deactivated_at              :datetime
#  recovery_available_at       :datetime
#  early_termination_available_at :datetime
#  discard_at                :datetime         default(Infinity), not null
#  last_step_up_at             :datetime
#  lock_version                :integer          default(0), not null
#  purge_eligible_at                   :datetime         default(Infinity), not null
#  reactivated_at              :datetime
#  terminated_at               :datetime
#  token_valid_after_at        :datetime
#  webauthn_user_handle        :string           not null
#  withdrawal_started_at       :datetime
#  withdrawn_at                :datetime         default(Infinity)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  admin_locked_by_operator_id :bigint
#  security_mode_id            :bigint           not null
#  mfa_status_id               :bigint           default(5), not null
#  public_id                   :string(255)      default(""), not null
#  status_id                   :bigint           default(11), not null
#  visibility_id               :bigint           default(2), not null
#
# Indexes
#
#  index_clients_on_access_state           (access_state)
#  index_clients_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_clients_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_clients_on_discard_at           (discard_at)
#  index_clients_on_security_mode_id       (security_mode_id)
#  index_clients_on_mfa_status_id          (mfa_status_id)
#  index_clients_on_public_id              (public_id) UNIQUE
#  index_clients_on_purge_eligible_at              (purge_eligible_at) WHERE (purge_eligible_at IS NOT NULL)
#  index_clients_on_status_id              (status_id)
#  index_clients_on_terminated_at          (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_clients_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_clients_on_visibility_id          (visibility_id)
#  index_clients_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_clients_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_clients_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (security_mode_id => client_security_modes.id)
#  fk_rails_...  (mfa_status_id => client_mfa_statuses.id)
#  fk_rails_...  (status_id => client_statuses.id)
#  fk_rails_...  (visibility_id => client_visibilities.id)
#

# Lifecycle column reference (see adr/retention-lifecycle-column-boundary.md):
#
# * `discard_at` / `purge_eligible_at` -- Retainable retention contract. The only
#   columns the `RetentionPurgeJob` consults for delete eligibility.
# * `withdrawal_started_at` -- Sign-out / withdrawal flow started.
# * `withdrawn_at` -- Withdrawal flow finalized. Retention is independent.
# * `deactivated_at` -- Withdrawal/suspension lifecycle marker. Reversible. Not a
#   deletion signal. Forced administrative access removal is represented by
#   `access_state: "admin_locked"` plus the `admin_locked_*` metadata columns.
# * `terminated_at` is not a PII erasure receipt: early termination can precede
#   identifier retention and legal-hold expiry. Retained Identity rows preserve
#   audit linkage; identifier-only purge preserves their dead histories.
class Client < AppPrincipalRecord
  include Retainable

  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }
  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update
  Retainable.register_host(self)

  include Withdrawable

  scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  include HasBirthdate

  encrypts :birthdate
  validates :birthdate, length: { maximum: 10 }, allow_blank: true
  validate :birthdate_format
  validate :birthdate_not_future
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :ensure_webauthn_user_handle, on: :create
  before_validation :assign_calculated_mfa_status, if: :mfa_status_placeholder?
  # before_save covers writes with validation disabled so the database NOT NULL still holds.
  before_save :ensure_webauthn_user_handle
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include ::Identity
  include AuthenticationCredentialInventoryOwner
  include WebauthnUserHandleOwner

  validates :webauthn_user_handle, presence: true, uniqueness: true
  include SecurityModeConfigurable
  include MfaStatusTrackable

  after_create :refresh_mfa_status!
  include ActorLifecycleConsistency

  validate :lifecycle_timestamps_are_consistent
  include AdministrativeAccessLockable

  attribute :access_state, :string, default: AdministrativeAccessLockable::ACCESS_STATE_ENABLED
  validates :access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
  validates :admin_locked_reason_code,
            inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES },
            allow_nil: true,
            if: :admin_locked_reason_code_column?
  validate :administrative_lock_columns_are_consistent

  LOGIN_BLOCKED_STATUS_IDS = [ClientStatus::RESERVED].freeze
  # D-106 (WU-34): statuses of a registration that has not reached its decisive commit (D-131).
  UNFINISHED_REGISTRATION_STATUS_IDS = [ClientStatus::UNVERIFIED_WITH_SIGN_UP].freeze
  # what is this?
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    ClientTelephoneStatus::VERIFIED,
    ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.user.recovery_identity_required")

  encrypts :admin_locked_reason_note

  attribute :status_id, default: ClientStatus::NOTHING

  validates :authentication_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  belongs_to :user_status, class_name: "ClientStatus",
                           foreign_key: :status_id,
                           inverse_of: :users
  belongs_to :security_mode,
             class_name: "ClientSecurityMode",
             inverse_of: :users
  belongs_to :mfa_status,
             class_name: "ClientMfaStatus",
             inverse_of: :users
  belongs_to :visibility,
             class_name: "ClientVisibility",
             inverse_of: :users
  has_many :outgoing_enterprise_ownership_transfer_requests,
           class_name: "EnterpriseOwnershipTransferRequest", foreign_key: :source_client_id,
           inverse_of: :source_client, dependent: :restrict_with_error
  has_many :incoming_enterprise_ownership_transfer_requests,
           class_name: "EnterpriseOwnershipTransferRequest", foreign_key: :destination_client_id,
           inverse_of: :destination_client, dependent: :restrict_with_error
  has_many :outgoing_client_persona_ownership_transfer_requests,
           class_name: "ClientPersonaOwnershipTransferRequest", foreign_key: :source_client_id,
           inverse_of: :source_client, dependent: :restrict_with_error
  has_many :incoming_client_persona_ownership_transfer_requests,
           class_name: "ClientPersonaOwnershipTransferRequest", foreign_key: :destination_client_id,
           inverse_of: :destination_client, dependent: :restrict_with_error

  has_many :enforcement_recovery_ceremonies, class_name: "ClientEnforcementRecoveryCeremony",
                                             inverse_of: :client, dependent: :restrict_with_error
  has_many :secret_issuances, class_name: "ClientSecretIssuance",
                              inverse_of: :client, dependent: :restrict_with_error
  has_many :registration_completions, class_name: "ClientRegistrationCompletion",
                                      inverse_of: :client, dependent: :restrict_with_error
  has_many :client_profiles, foreign_key: :user_id, inverse_of: :user, dependent: :restrict_with_error

  has_many :client_external_identities,
           dependent: :destroy,
           inverse_of: :client
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client
  has_many :client_emails,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_telephones,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_secret_credentials,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :client_totp_credentials,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_passkeys,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_withdrawal_flows,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :client_withdrawal_ceremonies,
           dependent: :delete_all,
           inverse_of: :client
  has_many :client_privacy_requests,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :client_retention_holds,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :active_totps,
           -> { where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE) },
           class_name: "ClientTotpCredential",
           dependent: :restrict_with_exception,
           inverse_of: :user

  # Cross-database (chronicle DB): append-only audit history. No dependent:
  # cascade -- audit records intentionally outlive actor purge and are not
  # deleted across the DB boundary. See adr/chronicle-audit-db-consolidation.md.
  has_many :client_chronicles, # rubocop:disable Rails/HasManyOrHasOneDependent
           foreign_key: :subject_id,
           inverse_of: false

  has_many :client_memberships,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  # Cross-database (chronicle DB), polymorphic audit history. No dependent:
  # cascade -- see client_chronicles above.
  has_many :staff_chronicles, class_name: "OperatorChronicle", as: :actor # rubocop:disable Rails/HasManyOrHasOneDependent
  # Cross-database (app_signal DB). Lifecycle is NOT an implicit AR cascade
  # across the DB boundary; purged explicitly via
  # RetentionCrossDatabaseChildPurge from the account purge path.
  has_many :notification_records, # rubocop:disable Rails/HasManyOrHasOneDependent
           class_name: "ClientNotificationRecord",
           foreign_key: :user_id,
           inverse_of: :client
  has_many :clients,
           class_name: "ClientProfile",
           foreign_key: :user_id,
           dependent: :restrict_with_error,
           inverse_of: false
  has_many :client_banners,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_members,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_discoveries,
           class_name: "ClientMemberDiscovery",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_observations,
           class_name: "ClientMemberObservation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_revocations,
           class_name: "ClientMemberRevocation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_impersonations,
           class_name: "ClientMemberImpersonation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_suspensions,
           class_name: "ClientMemberSuspension",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_deletions,
           class_name: "ClientMemberDeletion",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :members,
           through: :client_members
  has_many :owned_members,
           class_name: "Member",
           foreign_key: :user_id,
           dependent: :restrict_with_error,
           inverse_of: :user
  has_many :client_bulletins, foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_one :rp_account, class_name: "ClientAccount", foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_many :client_persona_ownerships, dependent: :restrict_with_error, inverse_of: :client
  has_many :owned_client_personas, through: :client_persona_ownerships, source: :client_persona
  has_many :client_persona_administration_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :client_persona_delegation_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :client_persona_usage_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :client_persona_view_grants, dependent: :restrict_with_error, inverse_of: :client
  has_one :authority_lock,
          class_name: "ClientAuthorityLock",
          dependent: :destroy,
          inverse_of: :client
  has_many :enterprise_ownerships, dependent: :restrict_with_error, inverse_of: :client
  has_many :owned_enterprises, through: :enterprise_ownerships, source: :enterprise
  has_many :enterprise_administration_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :enterprise_delegation_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :enterprise_view_grants, dependent: :restrict_with_error, inverse_of: :client
  has_many :core_app_client_bridges,
           dependent: :destroy,
           inverse_of: :client
  has_one :client_preference, class_name: "ClientPreference", dependent: :destroy,
                              inverse_of: :client
  # Cross-database (avatar DB). Join rows are purged explicitly via
  # RetentionCrossDatabaseChildPurge, not by an implicit cross-DB cascade.
  has_many :avatar_assignments, foreign_key: :user_id, inverse_of: :user # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :assigned_avatars, through: :avatar_assignments, source: :avatar

  validates :status_id, numericality: { only_integer: true }
  validates :public_id, uniqueness: true, length: { maximum: 21 }

  before_destroy :admit_identifier_history_erasure, prepend: true

  mfa_status_reference ClientMfaStatus

  before_destroy :erase_dead_identifier_histories

  # These checks run after authorized history erasure; retained rows still prevent deletion.
  has_many :email_histories, class_name: "ClientEmailHistory", foreign_key: :user_id,
                             inverse_of: :user, dependent: :restrict_with_error
  has_many :telephone_histories, class_name: "ClientTelephoneHistory", foreign_key: :user_id,
                                 inverse_of: :user, dependent: :restrict_with_error

  public
  def totp_enabled?
    if client_totp_credentials.loaded?
      client_totp_credentials.any? { |otp| otp.user_totp_credential_status_id == ClientTotpCredentialStatus::ACTIVE }
    else
      client_totp_credentials.exists?(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    end
  end

  def staff?
    false
  end

  def user?
    true
  end

  def client?
    true
  end

  # what is this?
  def has_verified_recovery_identity?
    has_verified_pii?
  end

  def has_verified_pii?
    verified_email? || verified_telephone?
  end

  def verified_email?
    # Only an effective binding identifies the Client (D-85); a verified-status candidate does not.
    return client_emails.any? { |e|
      e.binding_effective? && VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.user_email_status_id)
    } if client_emails.loaded?

    client_emails.effective_binding.exists?(user_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
  end

  def verified_telephone?
    return client_telephones.any? { |t|
      t.binding_effective? && VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.user_identity_telephone_status_id)
    } if client_telephones.loaded?

    client_telephones.effective_binding.exists?(
      user_identity_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS,
    )
  end

  private

  def admit_identifier_history_erasure
    with_lock do
      now = self.class.database_now
      if !lapsed?(now) || !purgeable?(now) || client_retention_holds.active_at(now).exists? ||
          AppEnforcementCase.principal_effect_blocking?(public_id, :withdrawal_purge_blocked) ||
          AppEnforcementCase.principal_effect_blocking?(public_id, :principal_hard_delete_blocked)
        errors.add(:base, "Identity is recoverable or legally retained")
        throw(:abort)
      end

      if notification_records.exists? || avatar_assignments.exists?
        errors.add(:base, "Cross-database children require the account purge workflow")
        throw(:abort)
      end
    end
  end

  def erase_dead_identifier_histories
    ClientEmailHistory.where(user_id: id).delete_all
    ClientTelephoneHistory.where(user_id: id).delete_all
    association(:email_histories).reset
    association(:telephone_histories).reset
  end

  def configured_mfa_level_methods
    step_up_methods
  end
end
