# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_secret_credentials
# Database name: org_principal
#
#  id                              :bigint           not null, primary key
#  consumed_at                     :datetime
#  delivery_method                 :string
#  discard_at                    :datetime         default(Infinity), not null
#  failure_count                   :integer          default(0), not null
#  issued_at                       :datetime
#  issued_by_ref                   :string
#  issued_by_type                  :string
#  last_failed_at                  :datetime
#  last_used_at                    :datetime
#  locked_at                       :datetime
#  lookup_digest                   :string
#  max_failures                    :integer
#  max_uses                        :integer
#  name                            :string           not null
#  not_before_at                   :datetime
#  password_digest                 :string
#  purge_eligible_at                       :datetime         default(Infinity), not null
#  revoked_at                      :datetime
#  safe_prefix                     :string
#  scope                           :string
#  secret_kind                     :string
#  usage_policy                    :string
#  use_count                       :integer          default(0), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  issued_by_id                    :bigint
#  public_id                       :string(21)       not null
#  staff_id                        :bigint           not null
#  staff_identity_secret_status_id :bigint           default(1), not null
#  staff_secret_kind_id            :bigint           default(2), not null
#
# Indexes
#
#  idx_on_staff_identity_secret_status_id_1e2bab9ca1          (staff_identity_secret_status_id)
#  index_operator_secret_credentials_on_lookup_digest         (lookup_digest)
#  index_operator_secret_credentials_on_public_id             (public_id) UNIQUE
#  index_operator_secret_credentials_on_staff_id              (staff_id)
#  index_operator_secret_credentials_on_staff_secret_kind_id  (staff_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...                              (staff_id => operators.id)
#  fk_rails_...                              (staff_identity_secret_status_id => operator_secret_credential_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => operator_secret_credential_kinds.id)
#

class OperatorSecretCredential < OrgPrincipalRecord
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
  include ::SecretCredential

  has_secure_password algorithm: :argon2, validations: false
  validates :name, presence: true
  validates :password,
            length: {
              is: SECRET_PASSWORD_LENGTH,
              message: "must be #{SECRET_PASSWORD_LENGTH} characters",
            },
            allow_nil: true
  validate :new_axis_secret_fields_are_consistent
  include OperatorSecretCredentialKinds

  MAX_SECRETS_PER_STAFF = 20
  ACTIVE_STATUS_IDS = [OperatorSecretCredentialStatus::ACTIVE].freeze

  alias_attribute :staff_secret_status_id, :staff_identity_secret_status_id

  attr_accessor :raw_secret_credential

  attribute :staff_identity_secret_status_id, default: OperatorSecretCredentialStatus::ACTIVE
  attribute :staff_secret_kind_id, default: OperatorSecretCredentialKind::LOGIN

  belongs_to :staff, class_name: "Operator"
  belongs_to :staff_secret_credential_status, class_name: "OperatorSecretCredentialStatus",
                                              inverse_of: :staff_secret_credentials,
                                              foreign_key: :staff_identity_secret_status_id
  belongs_to :staff_secret_credential_kind, class_name: "OperatorSecretCredentialKind",
                                            inverse_of: :staff_secret_credentials,
                                            foreign_key: :staff_secret_kind_id

  validates :staff_identity_secret_status_id, numericality: { only_integer: true }
  validates :staff_secret_kind_id, numericality: { only_integer: true }
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_secret_credentials,
                 foreign_key: :staff_id,
                 limit: :MAX_SECRETS_PER_STAFF,
                 record_name: "secret_credentials",
                 owner_name: "staff"

  def self.identity_secret_credential_status_class
    OperatorSecretCredentialStatus
  end
  public_class_method :identity_secret_credential_status_class

  def self.identity_secret_credential_status_id_column
    :staff_identity_secret_status_id
  end
  public_class_method :identity_secret_credential_status_id_column

  def self.generate_raw_secret_credential(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end
  public_class_method :generate_raw_secret_credential

  public
  def to_param
    public_id
  end
end
