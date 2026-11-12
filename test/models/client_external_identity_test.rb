# frozen_string_literal: true

require "test_helper"

class ClientExternalIdentityTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "a social link receipt prevents identity deletion through model and SQL" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    identity = ClientExternalIdentity.create!(
      client: client, provider: "google", issuer: "https://accounts.google.com",
      subject: "receipt-#{SecureRandom.uuid}", audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1", verified_at: Time.current,
    )
    receipt = ClientSocialLinkSourceReceipt.create!(
      client_external_identity: identity, admission_ref: PublicId.generate,
      actor_ref: client.public_id, provider: "google", committed_at: Time.current,
    )

    assert_not identity.destroy
    assert_predicate identity.errors[:base], :present?
    assert_predicate receipt.reload, :persisted?
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientExternalIdentity.transaction(requires_new: true) {
          ClientExternalIdentity.where(id: identity.id).delete_all
        }
      end

    assert_kind_of PG::RestrictViolation, error.cause
  end

  test "deterministically encrypts a provider subject while preserving subject lookup" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    stored_value = ClientExternalIdentity.connection.select_value(
      ClientExternalIdentity.where(id: identity.id).select(:subject).to_sql,
    )

    assert_not_includes stored_value, "apple-subject-1"
    assert_equal identity, ClientExternalIdentity.find_by!(
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
    )
    assert_predicate identity, :active?
  end

  test "allows one effective external identity binding per client" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-1",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.current,
    )

    duplicate = ClientExternalIdentity.new(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-2",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.current,
    )

    assert_predicate duplicate, :invalid?
    assert duplicate.errors.of_kind?(:client_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientExternalIdentity.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "touch_authenticated! records the latest sign-in without touching the binding" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-touch-#{SecureRandom.hex(4)}",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    assert_nil identity.last_authenticated_at

    identity.touch_authenticated!

    assert_not_nil identity.reload.last_authenticated_at
    assert_equal Time.utc(2026, 7, 24, 12, 0, 0), identity.verified_at
  end
end
