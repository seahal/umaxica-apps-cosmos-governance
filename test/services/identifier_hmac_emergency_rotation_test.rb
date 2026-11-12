# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentifierHmacEmergencyRotationTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @staff = operators(:one)
  end

  test "overwrites stale identifier digests across user and staff records" do
    user_email = ClientEmail.create!(
      user: @user,
      raw_address: "hmac-rotation-user-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    user_telephone = ClientTelephone.create!(
      user: @user,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )
    staff_email = OperatorEmail.create!(
      staff: @staff,
      raw_address: "hmac-rotation-staff-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    staff_telephone = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )

    records = [
      [user_email, :address, :address_digest, :bidx_for_email],
      [user_telephone, :number, :number_digest, :bidx_for_telephone],
      [staff_email, :address, :address_digest, :bidx_for_email],
      [staff_telephone, :number, :number_digest, :bidx_for_telephone],
    ]

    records.each do |record, _identifier_column, digest_column, _digest_method|
      record.update_columns(digest_column => "stale-#{SecureRandom.hex(24)}")
    end

    app_connection = AppZenithRecord.lease_connection.raw_connection
    org_connection = OrgZenithRecord.lease_connection.raw_connection
    app_email = IdentifierHmacEmergencyRotation.new(
      realm: "app", channel: "email", maintenance_connection: app_connection,
    ).call
    app_telephone = IdentifierHmacEmergencyRotation.new(
      realm: "app", channel: "telephone", maintenance_connection: app_connection,
    ).call
    org_email = IdentifierHmacEmergencyRotation.new(
      realm: "org", channel: "email", maintenance_connection: org_connection,
    ).call
    org_telephone = IdentifierHmacEmergencyRotation.new(
      realm: "org", channel: "telephone", maintenance_connection: org_connection,
    ).call

    assert_operator app_email.user_emails_updated, :>=, 1
    assert_operator app_telephone.user_telephones_updated, :>=, 1
    assert_operator org_email.staff_emails_updated, :>=, 1
    assert_operator org_telephone.staff_telephones_updated, :>=, 1
    [app_email, app_telephone, org_email, org_telephone].each do |result|
      assert_equal 0, result.records_failed
    end

    records.each do |record, _identifier_column, digest_column, _digest_method|
      record.reload
      expected =
        case record
        when ClientEmail, OperatorEmail
          IdentifierBlindIndex.bidx_for_email(record.address, realm: record.class.identifier_hmac_realm)
        when ClientTelephone, OperatorTelephone
          IdentifierBlindIndex.bidx_for_telephone(record.number, realm: record.class.identifier_hmac_realm)
        end

      # A failed comparison must not expose identifier lookup HMACs in test output.
      assert_withheld("The selected normalized identifier must match its current realm key") {
        expected == record[digest_column]
      }
    end
  end
end
