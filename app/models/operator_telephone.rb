# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephones
# Database name: org_principal
#
#  id                                 :bigint           not null, primary key
#  locked_at                          :datetime
#  number                             :string           not null
#  number_digest                      :string
#  otp_attempts_count                 :integer          default(0), not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  staff_id                           :bigint           not null
#  staff_identity_telephone_status_id :bigint           default(6), not null
#
# Indexes
#
#  idx_on_staff_identity_telephone_status_id_6c01767c57  (staff_identity_telephone_status_id)
#  index_operator_telephones_on_number_digest            (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_operator_telephones_on_staff_id                 (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_telephone_status_id => operator_telephone_statuses.id)
#

class OperatorTelephone < OrgPrincipalRecord
  # Issued public IDs are also protected by operator_telephones_public_id_immutability;
  # the scoped DB exception is owned by adr/database-trigger-usage-boundary.md.
  include PublicId

  after_initialize :initialize_telephone_otp_state
  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :normalize_number_from_raw
  before_validation :set_number_digests
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include Telephone

  scope :with_number, ->(value) do
    digest = IdentifierBlindIndex.bidx_for_telephone(value, realm: identifier_hmac_realm)
    digest.present? ? where(number_digest: digest) : none
  end
  validate :validate_telephone_number
  validates :confirm_policy, acceptance: true,
                             unless: proc { |record| record.raw_number.blank? && record.pass_code.present? }
  validates :confirm_using_mfa, acceptance: true,
                                unless: proc { |record| record.raw_number.blank? && record.pass_code.present? }
  validates :pass_code, numericality: { only_integer: true },
                        length: { is: 6 },
                        presence: true,
                        unless: proc { |record| record.pass_code.blank? && record.raw_number.present? }
  include TelephoneDeadIdentifierHistory

  IDENTIFIER_REALM = "org"

  MAX_TELEPHONES_PER_STAFF = 4

  encrypts :number, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  alias_attribute :staff_telephone_status_id, :staff_identity_telephone_status_id
  attribute :staff_identity_telephone_status_id, default: OperatorTelephoneStatus::UNVERIFIED

  belongs_to :staff_telephone_status, class_name: "OperatorTelephoneStatus",
                                      foreign_key: :staff_identity_telephone_status_id,
                                      inverse_of: :staff_telephones
  belongs_to :staff, class_name: "Operator"

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :staff_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, blind_index_uniqueness: { error_attribute: :number }, allow_nil: true

  before_destroy :archive_dead_telephone_identifier, prepend: true

  self.filter_attributes += %w(number)

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_telephones,
                 foreign_key: :staff_id,
                 limit: :MAX_TELEPHONES_PER_STAFF,
                 record_name: "telephones",
                 owner_name: "staff"

  after_initialize do
    self.number ||= ""
  end

  # Note: :number encryption is handled by Telephone concern

  public

  private
end
