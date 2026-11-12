# typed: false
# frozen_string_literal: true

# Builds retained ClientExternalIdentity records for model and account-capability tests.
module ExternalIdentityTestHelper
  ISSUERS = {
    "apple" => "https://appleid.apple.com",
    "google" => "https://accounts.google.com",
  }.freeze

  AUDIENCES = {
    "apple" => "apple-test-client-id",
    "google" => "google-test-client-id",
  }.freeze

  def create_active_external_identity(client:, provider:, subject: "#{provider}-subject-#{SecureRandom.hex(8)}",
                                      state: "active")
    ClientExternalIdentity.create!(
      client: client,
      provider: provider,
      issuer: ISSUERS.fetch(provider),
      subject: subject,
      audience: AUDIENCES.fetch(provider),
      verification_authority: "test",
      verified_at: Time.current,
      state: state,
    )
  end
end
