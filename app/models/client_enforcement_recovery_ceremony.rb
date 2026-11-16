# typed: false
# frozen_string_literal: true

class ClientEnforcementRecoveryCeremony < AppPrincipalRecord
  include EnforcementRecoveryCeremonyRecordable
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_token, on: :create
  before_validation :assign_expiry, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  attr_reader :plaintext_token

  validates :status_id, inclusion: { in: [ACTIVE, CONSUMED, REVOKED] }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  belongs_to :client, inverse_of: :enforcement_recovery_ceremonies

  def self.subject_association_name = :client
  public_class_method :subject_association_name

  public
  def subject = Client.find(client_id)
end
