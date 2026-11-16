# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpAvailableMethodsTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  setup do
    @user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING)
    @staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
  end

  test "includes email_otp for verified user email status" do
    email = @user.client_emails.create!(
      address: "verified-stepup@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)

    assert_includes StepUpAvailableMethods.call(@user), :email_otp
  end

  test "matches configured methods without cooldown or lockout" do
    email = @user.client_emails.create!(
      address: "available-baseline@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)

    assert_equal StepUpConfiguredMethodsQuery.call(@user), StepUpAvailableMethods.call(@user)
  end

  test "verified email and an active Passkey are both available" do
    email = @user.client_emails.create!(
      address: "available-cooldown@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)
    passkey = @user.client_passkeys.new(
      webauthn_id: "available_cooldown_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "cooldown passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    result = StepUpAvailableMethods.call(@user)

    assert_includes result, :email_otp
    assert_includes result, :passkey
  end

  test "ticket lockout returns no methods" do
    email = @user.client_emails.create!(
      address: "available-lockout@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)
    ticket = Struct.new(:attempt_count).new(5)

    assert_equal [], StepUpAvailableMethods.call(@user, ticket: ticket)
  end

  test "ticket attempt count four still returns configured methods" do
    email = @user.client_emails.create!(
      address: "available-attempt-four@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)
    ticket = Struct.new(:attempt_count).new(4)

    assert_includes StepUpAvailableMethods.call(@user, ticket: ticket), :email_otp
  end

  test "does not include email_otp for unverified user email status" do
    @user.client_emails.create!(
      address: "unverified-stepup@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_not_includes StepUpAvailableMethods.call(@user), :email_otp
  end

  test "includes passkey for active passkey status" do
    passkey =
      @user.client_passkeys.new(
        webauthn_id: "stepup_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "stepup passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )
    passkey.save!(validate: false)

    assert_includes StepUpAvailableMethods.call(@user), :passkey
  end

  test "does not include passkey for inactive passkey status" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey =
      user.client_passkeys.new(
        webauthn_id: "stepup_inactive_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "inactive passkey",
        status_id: ClientPasskeyStatus::DISABLED,
      )
    passkey.save!(validate: false)

    assert_not_includes StepUpAvailableMethods.call(user), :passkey
  end

  test "includes totp for active totp status" do
    @user.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_includes StepUpAvailableMethods.call(@user), :totp
  end

  test "does not include totp for inactive totp status" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    user.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_not_includes StepUpAvailableMethods.call(user), :totp
  end

  test "does not include email_otp for active staff email status" do
    @staff.operator_emails.create!(
      address: "staff-active-stepup@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::ACTIVE,
    )

    assert_not_includes StepUpAvailableMethods.call(@staff), :email_otp
  end

  test "available methods apply lockout for staff actors" do
    passkey = @staff.operator_passkeys.new(
      webauthn_id: "staff_lockout_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "staff lockout passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)
    ticket = Struct.new(:attempt_count).new(5)

    assert_equal [], StepUpAvailableMethods.call(@staff, ticket: ticket)
  end

  test "does not include email_otp for inactive staff email status" do
    @staff.operator_emails.create!(
      address: "staff-inactive-stepup@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::INACTIVE,
    )

    assert_not_includes StepUpAvailableMethods.call(@staff), :email_otp
  end
end
