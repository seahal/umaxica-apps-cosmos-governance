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
  include Telephone
  include TelephoneDeadIdentifierHistory

  include PublicId
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

  after_initialize :initialize_telephone_otp_state

  before_destroy :archive_dead_telephone_identifier, prepend: true

  after_initialize do
    self.number ||= ""
  end

  scope :effective_binding, -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) }

  public

  def to_param
    public_id
  end

  def finalize_sign_up_binding!(flow:, transaction:, session_nonce:)
    raise AccessOpDataUnavailableError
  end

  def contact_binding_digest
    number_digest
  end

  # Note: :number encryption is handled by Telephone concern

  private
end
