# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpConfiguredMethodsTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @user = clients(:one)
  end

  test "does not include email_otp for unverified email" do
    @user.client_emails.create!(
      address: "configured-unverified@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_not_includes StepUpConfiguredMethodsQuery.call(@user), :email_otp
  end

  test "includes email_otp for verified email" do
    email = @user.client_emails.create!(
      address: "configured-verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.update_columns(binding_finalized_at: email.class.database_now)

    assert_includes StepUpConfiguredMethodsQuery.call(@user), :email_otp
  end

  test "returns credential-backed staff methods" do
    staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::BOTH,
    )
    staff.operator_emails.create!(
      address: "configured-staff@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::ACTIVE,
    )
    passkey = staff.operator_passkeys.new(
      webauthn_id: "configured_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "staff passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    result = StepUpConfiguredMethodsQuery.call(staff)

    assert_not_includes result, :email_otp
    assert_includes result, :passkey
    assert_not_includes result, :totp
  end

  test "does not include inactive totp" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    user.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_not_includes StepUpConfiguredMethodsQuery.call(user), :totp
  end

  test "does not include inactive passkey" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey =
      user.client_passkeys.new(
        webauthn_id: "configured_inactive_passkey_#{SecureRandom.hex(4)}",
        external_id: SecureRandom.uuid,
        public_key: "public_key",
        sign_count: 0,
        description: "inactive passkey",
        status_id: ClientPasskeyStatus::DISABLED,
      )
    passkey.save!(validate: false)

    assert_not_includes StepUpConfiguredMethodsQuery.call(user), :passkey
  end
end
