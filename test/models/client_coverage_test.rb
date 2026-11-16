# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientCoverageTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: 1)
    ClientVisibility.find_or_create_by!(id: 1)
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000), status_id: 1, visibility_id: 1,
    )
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientTotpCredentialStatus.find_or_create_by!(id: ClientTotpCredentialStatus::ACTIVE)
  end

  test "totp_enabled?" do
    assert_not @user.totp_enabled?
    ClientTotpCredential.create!(
      user: @user,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_predicate @user, :totp_enabled?

    @user = Client.includes(:client_totp_credentials).find(@user.id)

    assert_predicate @user, :totp_enabled?
  end

  test "staff? and user? predicates" do
    assert_not @user.staff?
    assert_predicate @user, :user?
  end

  test "verified_email? and verified_telephone?" do
    assert_not @user.verified_email?
    ClientEmail.create!(user: @user, address: "v@example.com", user_email_status_id: ClientEmailStatus::VERIFIED)
      .tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }

    assert_predicate @user, :verified_email?

    assert_not @user.verified_telephone?
    ClientTelephone.create!(
      user: @user, number: "+819012345678", user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    ).tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }

    assert_predicate @user, :verified_telephone?
  end

  test "withdrawal and deactivation predicates" do
    assert_not @user.withdrawal_started?
    assert_not @user.deactivated?
    assert_not @user.withdrawal_in_progress?

    @user.update!(withdrawal_started_at: Time.current)

    assert_predicate @user, :withdrawal_started?
    assert_predicate @user, :withdrawal_in_progress?

    @user.update!(deactivated_at: Time.current)

    assert_predicate @user, :deactivated?
    assert_predicate @user, :withdrawal_in_progress?
  end

  test "ClientEmail verification tokens" do
    email = ClientEmail.create!(user: @user, address: "token@example.com", user_email_status_id: 1)
    raw = email.generate_verification_token

    assert_not_nil raw
    assert email.verify_verification_token(raw)
    assert_not email.verify_verification_token("wrong")
  end
end
