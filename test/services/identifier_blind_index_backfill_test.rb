# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentifierBlindIndexBackfillTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @staff = operators(:one)
  end

  test "backfills missing digests with the owning realm keys" do
    user_email = ClientEmail.create!(
      raw_address: "backfill-user-email@example.com",
      confirm_policy: true,
      user: @user,
    )
    user_telephone = ClientTelephone.create!(
      raw_number: "+1 (555) 222-3333",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )
    staff_email = OperatorEmail.create!(
      raw_address: "backfill-staff-email@example.com",
      confirm_policy: true,
      staff: @staff,
    )
    staff_telephone = OperatorTelephone.create!(
      raw_number: "+1 (555) 444-5555",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    )

    user_email.update_columns(address_digest: nil)
    user_telephone.update_columns(number_digest: nil)
    staff_email.update_columns(address_digest: nil)
    staff_telephone.update_columns(number_digest: nil)

    result = IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-user-email@example.com", realm: :app),
                 user_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15552223333", realm: :app),
                 user_telephone.reload.number_digest
    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-staff-email@example.com", realm: :org),
                 staff_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15554445555", realm: :org),
                 staff_telephone.reload.number_digest

    assert_operator result.user_emails_updated, :>=, 1
    assert_operator result.user_telephones_updated, :>=, 1
    assert_operator result.staff_emails_updated, :>=, 1
    assert_operator result.staff_telephones_updated, :>=, 1
  end

  test "is idempotent when digests are already current" do
    staff_email = OperatorEmail.create!(
      raw_address: "idempotent-staff@example.com",
      confirm_policy: true,
      staff: @staff,
    )

    IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("idempotent-staff@example.com", realm: :org),
                 staff_email.reload.address_digest
  end

  test "malformed persisted identifier aborts backfill instead of reporting silent partial success" do
    record = OperatorEmail.create!(
      staff: @staff, raw_address: "invalid-backfill@example.com", confirm_policy: true,
    )
    record.update_columns(address: "not-an-email")

    assert_raises(ArgumentError) { IdentifierBlindIndexBackfill.new.call }
    assert_equal "not-an-email", record.reload.address
  end

  test "malformed persisted telephone aborts backfill instead of reporting silent partial success" do
    record = OperatorTelephone.create!(
      staff: @staff, raw_number: "+819012399905", confirm_policy: true, confirm_using_mfa: true,
    )
    record.update_columns(number: "not-a-number")

    assert_raises(ArgumentError) { IdentifierBlindIndexBackfill.new.call }
    assert_equal "not-a-number", record.reload.number
  end
end
