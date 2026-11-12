# frozen_string_literal: true

require "test_helper"

class AuthMethodGuardTest < ActiveSupport::TestCase
  fixtures :client_email_statuses, :client_telephone_statuses, :client_totp_credential_statuses,
           :operator_passkey_statuses

  test "verified email removal is refused until another sign-in and step-up method remains" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    now = Client.database_now
    email = ClientEmail.create!(
      user: client,
      address: "auth-guard-#{SecureRandom.uuid}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: now,
    )

    assert_not AuthMethodGuard.can_remove_email?(client, email)

    client.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid,
      public_key: "email-removal-fallback",
      uv_verified_at: now,
    )

    assert AuthMethodGuard.can_remove_email?(client, email)
  end

  test "telephone removal is refused when it is the only contact for an active secret credential" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    now = Client.database_now
    telephone = ClientTelephone.create!(
      user: client,
      number: "+819012345678",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: now,
    )
    issuance = ClientSecretIssuance.create!(
      client: client,
      origin_operation_id: SecureRandom.uuid,
      origin: "manual",
      attempt_number: 1,
      browser_session_ref: "telephone-guard-session",
      planned_count: 1,
      expires_at: now + 5.minutes,
      presented_at: now - 1.minute,
      confirmed_at: now,
    )
    ClientSecretCredential.create!(
      client: client,
      issuance: issuance,
      name: "Telephone-bound secret",
      password_digest: Argon2::Password.create("0123456789abcdef0123456789abcdef"),
      confirmed_at: now,
    )

    assert_not AuthMethodGuard.can_remove_telephone?(client, telephone)
  end

  test "TOTP removal is refused until another step-up method remains" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    now = Client.database_now
    totp = ClientTotpCredential.create!(
      user: client,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      private_key: ROTP::Base32.random_base32,
    )

    assert_not AuthMethodGuard.can_remove_totp?(client, totp)

    client.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid,
      public_key: "totp-removal-fallback",
      uv_verified_at: now,
    )

    assert AuthMethodGuard.can_remove_totp?(client, totp)
  end

  test "external identity removal is refused until another sign-in method remains" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "auth-guard-#{SecureRandom.uuid}",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2",
      verified_at: Time.current,
    )

    assert_not AuthMethodGuard.can_remove_external_identity?(client, identity)

    client.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid,
      public_key: "external-identity-removal-fallback",
      uv_verified_at: Client.database_now,
    )

    assert AuthMethodGuard.can_remove_external_identity?(client, identity)
  end

  test "ADVANCED operators keep two active passkeys after a proposed removal" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    now = Operator.database_now
    passkeys =
      2.times.map do
        OperatorPasskey.create!(
          staff: operator,
          webauthn_id: SecureRandom.uuid,
          public_key: "advanced-removal-#{SecureRandom.uuid}",
          uv_verified_at: now,
        )
      end

    assert_not AuthMethodGuard.can_remove_passkey?(operator, passkeys.first)

    last_passkey = OperatorPasskey.create!(
      staff: operator,
      webauthn_id: SecureRandom.uuid,
      public_key: "advanced-removal-#{SecureRandom.uuid}",
      uv_verified_at: now,
    )

    assert AuthMethodGuard.can_remove_passkey?(operator, last_passkey)
  end
end
