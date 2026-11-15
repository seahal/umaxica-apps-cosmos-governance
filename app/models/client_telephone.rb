# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_telephones
# Database name: app_principal
#
#  id                                :bigint           not null, primary key
#  discard_at                      :datetime         default(Infinity), not null
#  locked_at                         :datetime         default(-Infinity), not null
#  number                            :string           default(""), not null
#  number_digest                     :string
#  otp_attempts_count                :integer          default(0), not null
#  purge_eligible_at                         :datetime         default(Infinity), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  public_id                         :string(21)       not null
#  user_id                           :bigint           not null
#  user_identity_telephone_status_id :bigint           default(2), not null
#
# Indexes
#
#  index_client_telephones_on_active_number_digest               (number_digest) UNIQUE WHERE ((number_digest IS NOT NULL) AND (user_identity_telephone_status_id <> 4))
#  index_client_telephones_on_discard_at                       (discard_at)
#  index_client_telephones_on_public_id                          (public_id) UNIQUE
#  index_client_telephones_on_purge_eligible_at                          (purge_eligible_at)
#  index_client_telephones_on_user_id                            (user_id)
#  index_client_telephones_on_user_identity_telephone_status_id  (user_identity_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_telephone_status_id => client_telephone_statuses.id)
#

class ClientTelephone < AppPrincipalRecord
  include Retainable

  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }
  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update
  Retainable.register_host(self)

  include Telephone

  after_initialize :initialize_telephone_otp_state

  before_validation :normalize_number_from_raw
  before_validation :set_number_digests
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

  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include TelephoneContactBinding

  IDENTIFIER_REALM = "app"
  encrypts :number, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  self.filter_attributes += %w(number)

  alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id

  attribute :user_identity_telephone_status_id, default: ClientTelephoneStatus::UNVERIFIED

  belongs_to :user_telephone_status,
             class_name: "ClientTelephoneStatus",
             inverse_of: :client_telephones,
             foreign_key: :user_identity_telephone_status_id
  belongs_to :user, class_name: "Client", inverse_of: :client_telephones

  validates :number_digest,
            contact_binding_uniqueness: {
              error_attribute: :number,
              conditions: -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) },
            },
            if: -> {
              binding_effective? &&
                (will_save_change_to_number_digest? || will_save_change_to_binding_finalized_at? ||
                  will_save_change_to_binding_released_at?)
            }
  validates :user_id,
            uniqueness: { conditions: -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) } },
            if: -> {
              binding_effective? &&
                (will_save_change_to_user_id? || will_save_change_to_binding_finalized_at? ||
                  will_save_change_to_binding_released_at?)
            }

  validate :effective_binding_has_digest

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :user_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, presence: true, if: :binding_effective?

  before_destroy :archive_dead_telephone_identifier, prepend: true

  after_initialize do
    self.number ||= ""
  end

  scope :effective_binding, -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) }

  public

  def to_param
    public_id
  end

  def contact_binding_digest
    number_digest
  end

  # Note: :number encryption is handled by Telephone concern

  private
end
