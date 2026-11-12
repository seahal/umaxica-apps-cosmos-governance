# typed: false
# frozen_string_literal: true

require "test_helper"

# Channel policies retain independent failure and lockout behavior.
class OtpLockableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :operators, :operator_statuses

  test "Email and Telephone activate independent OTP policies" do
    assert_includes ClientEmail.included_modules, EmailOtpPolicy
    assert_not_includes ClientEmail.included_modules, TelephoneOtpPolicy
    assert_includes OperatorTelephone.included_modules, TelephoneOtpPolicy
    assert_not_includes OperatorTelephone.included_modules, EmailOtpPolicy
  end

  test "increment_attempts! does not run model validations" do
    # confirm_policy: false makes the record fail acceptance validation, so a
    # plain save! would raise. increment_attempts! must still succeed.
    telephone = OperatorTelephone.new(
      number: "+819012345678",
      staff: operators(:none_staff),
      confirm_policy: false,
    )
    telephone.save!(validate: false)

    assert_not telephone.valid?, "fixture should be invalid so the validate: false path is meaningful"

    # valid? dirties in-memory attributes (e.g. number_digest); discard them so
    # the row lock in increment_attempts! sees a clean persisted record.
    telephone.reload

    assert_nothing_raised { telephone.increment_attempts! }
    assert_equal 1, telephone.reload.otp_attempts_count
  end

  test "cooldown stays email-only so the resend ceremony branch is preserved" do
    assert_respond_to ClientEmail.new(user: clients(:none_user)), :otp_cooldown_active?
    assert_not OperatorTelephone.new(staff: operators(:none_staff)).respond_to?(:otp_cooldown_active?)
  end

  test "the lockout timestamp uses the same writer database clock as the failure increment" do
    database_now = Time.utc(2026, 9, 21, 14, 0, 0)
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "otp-lockout-database-clock@example.com",
      confirm_policy: true,
    )
    email.update_columns(
      otp_attempts_count: EmailOtpPolicy::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: database_now,
      locked_at: -Float::INFINITY,
    )

    ClientEmail.stub(:database_now, database_now) do
      email.increment_attempts!
    end

    assert_equal database_now + EmailOtpPolicy::OTP_LOCKOUT_DURATION, email.reload.locked_at
  end
end
