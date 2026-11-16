# typed: false
# frozen_string_literal: true

class ClientExternalIdentity < AppPrincipalRecord
  PROVIDERS = %w(apple google).freeze
  STATES = %w(active consent_revoked account_deleted).freeze

  encrypts :subject, deterministic: true

  alias_attribute :uid, :subject
  alias_attribute :user_id, :client_id

  belongs_to :client, inverse_of: :client_external_identities
  has_many :client_social_link_source_receipts,
           inverse_of: :client_external_identity,
           dependent: :restrict_with_error
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client_external_identity

  validates :client_id,
            uniqueness: { conditions: -> { where(released_at: nil) } },
            if: -> { released_at.nil? && (will_save_change_to_client_id? || will_save_change_to_released_at?) }
  validates :subject,
            uniqueness: { scope: :issuer, conditions: -> { where(released_at: nil) } },
            if: -> {
              released_at.nil? &&
                (will_save_change_to_subject? || will_save_change_to_issuer? || will_save_change_to_released_at?)
            }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :issuer, :subject, :audience, :verification_authority, presence: true
  validates :state, inclusion: { in: STATES }
  validates :verified_at, presence: true
  validates :provider, length: { maximum: 16 }
  validates :state, length: { maximum: 32 }

  scope :effective_binding, -> { where(released_at: nil) }

  def self.with_subject_lock(provider:, issuer:, subject:)
    raise ArgumentError, "social subject lock requires a Source transaction" unless lease_connection.transaction_open?
    raise ArgumentError, "social subject lock requires a block" unless block_given?

    key = Digest::SHA256.digest([provider, issuer, subject].join("\0")).unpack1("q>")
    # Only the derived signed integer enters SQL; the adapter cannot decode the lock function's void result.
    lease_connection.execute("SELECT pg_advisory_xact_lock(#{key.to_i})")
    yield
  end

  public_class_method :with_subject_lock

  alias_method :user, :client
  alias_method :user=, :client=

  def active?
    state == "active" && released_at.blank?
  end

  public :active?

  public
  def touch_authenticated!
    update!(last_authenticated_at: Time.current)
  end

  def release!(at: self.class.database_now)
    return self if released_at.present?

    update!(state: "consent_revoked", released_at: at)
  end
end
