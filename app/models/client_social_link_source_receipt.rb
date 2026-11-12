# frozen_string_literal: true

class ClientSocialLinkSourceReceipt < AppPrincipalRecord
  belongs_to :client_external_identity, inverse_of: :client_social_link_source_receipts

  validates :admission_ref, :actor_ref, :provider, :committed_at, presence: true
  validates :admission_ref,
            format: { with: /\A[A-Za-z0-9_-]{21}\z/ }, uniqueness: true
  validates :admission_ref, length: { maximum: 21 }
  validates :actor_ref, length: { maximum: 64 }
  validates :provider, inclusion: { in: ClientExternalIdentity::PROVIDERS }
  validates :provider, length: { maximum: 16 }
end
