# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_emails
# Database name: org_principal
#
#  id                             :bigint           not null, primary key
#  address                        :string           not null
#  address_digest                 :string
#  locked_at                      :datetime
#  notifiable                     :boolean          default(TRUE), not null
#  otp_attempts_count             :integer          default(0), not null
#  otp_last_sent_at               :datetime
#  promotional                    :boolean          default(TRUE), not null
#  subscribable                   :boolean          default(TRUE), not null
#  undeletable                    :boolean          default(FALSE), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       default(""), not null
#  staff_id                       :bigint           not null
#  staff_identity_email_status_id :bigint           default(6), not null
#
# Indexes
#
#  index_operator_emails_on_address_digest                  (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_operator_emails_on_public_id                       (public_id) UNIQUE
#  index_operator_emails_on_staff_id                        (staff_id)
#  index_operator_emails_on_staff_identity_email_status_id  (staff_identity_email_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_email_status_id => operator_email_statuses.id)
#

class OperatorEmail < OrgPrincipalRecord
  include PublicId

  after_initialize :initialize_email_otp_state
  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :normalize_address_from_raw
  before_validation :set_address_digests
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include Email

  scope :with_address, ->(value) do
    digest = IdentifierBlindIndex.bidx_for_email(value, realm: identifier_hmac_realm)
    digest.present? ? where(address_digest: digest) : none
  end
  validate :validate_email_address
  validates :confirm_policy, acceptance: true, on: :create,
                             unless: proc { |a| a.raw_address.blank? && a.pass_code.present? }
  validates :pass_code, numericality: { only_integer: true },
                        length: { is: 6 },
                        presence: true,
                        unless: proc { |a| a.pass_code.blank? && a.raw_address.present? }
  include EmailDeadIdentifierHistory

  include PromotionalEmailUnsubscribable

  IDENTIFIER_REALM = "org"

  MAX_EMAILS_PER_STAFF = 4

  encrypts :address, downcase: true,
                     key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  alias_attribute :staff_email_status_id, :staff_identity_email_status_id
  attribute :staff_identity_email_status_id, default: OperatorEmailStatus::UNVERIFIED
  belongs_to :staff_email_status, class_name: "OperatorEmailStatus",
                                  foreign_key: :staff_identity_email_status_id,
                                  inverse_of: :staff_emails
  belongs_to :staff, class_name: "Operator"
  validates :address, presence: true, length: { maximum: 255 }
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :staff_identity_email_status_id, numericality: { only_integer: true }
  validates :address_digest, blind_index_uniqueness: { error_attribute: :address }, allow_nil: true

  before_destroy :archive_dead_email_identifier, prepend: true

  self.filter_attributes += %w(address)

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_emails,
                 foreign_key: :staff_id,
                 limit: :MAX_EMAILS_PER_STAFF,
                 record_name: "emails",
                 owner_name: "staff"
  before_destroy :prevent_destroy_when_undeletable
  before_validation do
    self.staff_id ||= 0
  end

  public

  after_initialize do
    self.address ||= ""
  end

  def to_param
    public_id
  end

  def promotional_unsubscribe_scope
    :operator
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end
end
