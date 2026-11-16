# typed: false
# frozen_string_literal: true

require "test_helper"

# Test with ClientEmail which includes Email
class EmailTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_statuses, :operator_statuses

  setup do
    @user = clients(:none_user)
  end

  def build_email(attrs = {})
    ClientEmail.new({ user: @user }.merge(attrs))
  end

  def create_email(attrs = {})
    ClientEmail.create!({ user: @user }.merge(attrs))
  end

  test "concern can be included in a class" do
    assert_includes ClientEmail.included_modules, Email
  end

  test "concern adds confirm_policy accessor" do
    email = build_email

    assert_respond_to email, :confirm_policy
    assert_respond_to email, :confirm_policy=
  end

  test "concern adds pass_code accessor" do
    email = build_email

    assert_respond_to email, :pass_code
    assert_respond_to email, :pass_code=
  end

  test "downcases address before save" do
    email = build_email(address: "TEST@EXAMPLE.COM", confirm_policy: true)
    email.save!

    assert_equal "test@example.com", email.address
  end

  test "stores distinct ciphertexts for distinct addresses" do
    email1 = create_email(address: "test1@example.com", confirm_policy: true)
    email2 = create_email(address: "test2@example.com", confirm_policy: true)
    sql = "SELECT address FROM #{ClientEmail.table_name} WHERE id = :id"

    # Different emails should have different encrypted values
    raw1 = ClientEmail.connection.execute(
      ClientEmail.sanitize_sql_array([sql, { id: email1.id }]),
    ).first
    raw2 = ClientEmail.connection.execute(
      ClientEmail.sanitize_sql_array([sql, { id: email2.id }]),
    ).first

    assert_not_equal raw1["address"], raw2["address"]
  end

  test "validates email format with basic formats" do
    assert_predicate build_email(address: "test@example.com", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user+tag@example.co.jp", confirm_policy: true), :valid?
  end

  test "validates email format with consecutive special characters" do
    assert_predicate build_email(address: "user+tag@example.co.uk", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user+tag+123@example.com", confirm_policy: true), :valid?
  end

  test "validates email format with dots and underscores" do
    assert_predicate build_email(address: "user.name@example.com", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user_name@example.co.uk", confirm_policy: true), :valid?
  end

  test "validates email format with multiple domain levels" do
    assert_predicate build_email(address: "user@mail.example.co.uk", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user.tag@sub.example.com", confirm_policy: true), :valid?
  end

  test "validates email format with Gmail-style addressing" do
    assert_predicate build_email(address: "user+mailbox@gmail.com", confirm_policy: true), :valid?
  end

  test "validates email format with mixed special characters" do
    assert_predicate build_email(address: "user-name_tag+123@example.co.uk", confirm_policy: true), :valid?
  end

  test "validates email format with numeric addresses" do
    assert_predicate build_email(address: "1234567890@example.com", confirm_policy: true), :valid?
  end

  test "validates email format with single label domains and localhost" do
    assert_predicate build_email(address: "user@localhost", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user@example", confirm_policy: true), :valid?
  end

  test "rejects invalid email formats" do
    assert_not build_email(address: "invalid-email", confirm_policy: true).valid?
    assert_not build_email(address: "user@", confirm_policy: true).valid?
    assert_not build_email(address: "@example.com", confirm_policy: true).valid?
  end

  test "rejects email with spaces" do
    assert_not build_email(address: "user @example.com", confirm_policy: true).valid?
  end

  test "validates email presence" do
    email = build_email(address: nil, confirm_policy: true)

    assert_not email.valid?
    assert_predicate email.errors[:address], :any?
  end

  test "effective Email bindings enforce address uniqueness case insensitively at finalization" do
    existing =
      ClientEmail.create!(user: @user, address: "test@example.com", confirm_policy: true).tap { |binding_record|
        binding_record.update!(binding_finalized_at: Time.current)
      }
    duplicate = ClientEmail.create!(user: @user, address: "TEST@EXAMPLE.COM", confirm_policy: true)

    assert_equal existing.address_digest, duplicate.address_digest
    assert_predicate duplicate, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientEmail.transaction(requires_new: true) do
        duplicate.update_columns(binding_finalized_at: Time.current)
      end
    end
    assert_nil duplicate.reload.binding_finalized_at
    assert_predicate existing.reload, :binding_effective?
  end

  test "validates confirm_policy acceptance" do
    email = build_email(address: "test@example.com", confirm_policy: false)

    assert_not email.valid?
    assert_predicate email.errors[:confirm_policy], :any?
  end

  test "increment_attempts! increases otp_attempts_count atomically" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    initial_count = email.otp_attempts_count

    email.increment_attempts!

    assert_equal initial_count + 1, email.reload.otp_attempts_count
  end

  test "locked? returns false when attempts are below threshold" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    assert_not email.locked?

    (Email::MAX_OTP_ATTEMPTS - 1).times do
      email.increment_attempts!

      assert_not email.locked?
    end
  end

  test "locked? returns true when attempts reach threshold within observation window" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }

    assert_predicate email, :locked?
  end

  test "increment_attempts! sets lockout expiry when threshold is reached" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    # Initially locked_at should be a sentinel (infinity or nil)
    assert email.locked_at.nil? || email.locked_at == Float::INFINITY || email.locked_at.to_s == "infinity"

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }
    email.reload

    assert_predicate email.locked_at, :present?
    assert_not_equal email.locked_at, Float::INFINITY
    assert_not_equal email.locked_at, -Float::INFINITY
    assert_operator email.locked_at, :>, Time.current
    assert_operator email.locked_at, :<=, Email::OTP_LOCKOUT_DURATION.from_now
  end

  test "increment_attempts! keeps locked_at stable when incrementing beyond threshold" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }
    email.reload

    first_locked_at = email.locked_at

    assert_predicate first_locked_at, :present?
    assert_not_equal first_locked_at, Float::INFINITY
    assert_not_equal first_locked_at, -Float::INFINITY

    # Increment again beyond threshold
    email.increment_attempts!
    email.reload

    # locked_at should remain the same (idempotent)
    assert_equal first_locked_at.to_i, email.locked_at.to_i
  end

  test "increment_attempts! does not change locked_at if already set" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    initial_lock_time = 1.hour.from_now
    email.update!(locked_at: initial_lock_time, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    # Increment again
    email.increment_attempts!
    email.reload

    # locked_at should remain unchanged (idempotent)
    assert_equal initial_lock_time.to_i, email.locked_at.to_i
  end

  test "locked? returns true when locked_at is set" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(locked_at: 1.minute.from_now)

    assert_predicate email, :locked?
  end

  test "locked? returns false after lockout expires" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(locked_at: 1.second.ago, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    assert_not email.locked?
  end

  test "attempts outside observation window are retained and still reach lockout" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(
      otp_attempts_count: Email::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: (Email::OTP_ATTEMPT_WINDOW + 1.second).ago,
    )

    email.increment_attempts!

    assert_equal Email::MAX_OTP_ATTEMPTS, email.reload.otp_attempts_count
    assert_predicate email, :locked?
  end

  test "increment_attempts! is thread-safe under concurrent access" do
    email = create_email(address: "concurrent@example.com", confirm_policy: true)

    futures =
      10.times.map do
        Concurrent::Promises.future do
          10.times do
            ActiveRecord::Base.connection_pool.with_connection do
              # Use a fresh instance to better simulate concurrent requests
              ClientEmail.find(email.id).increment_attempts!
            end
          end
        end
      end

    Concurrent::Promises.zip(*futures).value!

    assert_equal Email::MAX_OTP_ATTEMPTS, email.reload.otp_attempts_count
    assert_predicate email, :locked?
  end

  test "validates pass_code presence when pass_code is not nil" do
    email = build_email(address: nil, pass_code: nil)

    assert_not email.valid?
  end

  test "validates pass_code length exactly 6" do
    email = build_email(address: "test@example.com", pass_code: "12345")

    assert_not email.valid?

    email = build_email(address: "test@example.com", pass_code: "1234567")

    assert_not email.valid?
  end

  test "validates pass_code is integer" do
    email = build_email(address: "test@example.com", pass_code: "12345a")

    assert_not email.valid?
  end

  test "otp_cooldown_active? and remaining" do
    email = create_email(address: "cooldown@example.com", confirm_policy: true)

    # Not active initially
    assert_not email.otp_cooldown_active?
    assert_equal 0, email.otp_cooldown_remaining

    # Active after send
    email.update!(otp_last_sent_at: Time.current)

    assert_predicate email, :otp_cooldown_active?
    assert_operator email.otp_cooldown_remaining, :>, 0

    # Not active after cooldown period
    email.update!(otp_last_sent_at: 2.minutes.ago)

    assert_not email.otp_cooldown_active?
    assert_equal 0, email.otp_cooldown_remaining

    # Handles sentinel -infinity
    email.update!(otp_last_sent_at: -Float::INFINITY)

    assert_not email.otp_cooldown_active?
  end

  test "reregistration_window_active? uses independent ten second window" do
    email = create_email(address: "rereg-window@example.com", confirm_policy: true)

    email.update!(otp_last_sent_at: 9.seconds.ago)

    assert_predicate email, :reregistration_window_active?

    email.update!(otp_last_sent_at: 11.seconds.ago)

    assert_not email.reregistration_window_active?

    email.update!(otp_last_sent_at: -Float::INFINITY)

    assert_not email.reregistration_window_active?
  end

  test "find_by_address returns the matching email or nil" do
    created = create_email(address: "findable@example.com", confirm_policy: true)

    assert_equal created, ClientEmail.public_send(:find_by_address, "findable@example.com")
    assert_nil ClientEmail.public_send(:find_by_address, "")
    assert_nil ClientEmail.public_send(:find_by_address, "missing@example.com")
  end
end
