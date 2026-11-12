# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class IdentifierEncryptionRotationDrillTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  setup do
    @user = clients(:one)
    @staff = operators(:one)
  end

  test "rotation drill preserves existing records visible on Base" do
    original_realm_providers =
      %w(app org).index_with do |realm|
        RealmIdentifierEncryptionKeyProvider.key_provider(realm: realm)
      end

    app_email_address = "rotation-app-email-#{SecureRandom.hex(4)}@example.com"
    app_telephone_number = "+1555#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}"
    staff_email_address = "rotation-org-email-#{SecureRandom.hex(4)}@example.com"

    old_app_email = ClientEmail.create!(
      user: @user,
      raw_address: app_email_address,
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    old_app_email.update!(binding_finalized_at: Time.current)
    old_app_telephone = ClientTelephone.create!(
      user: @user,
      raw_number: app_telephone_number,
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    old_app_telephone.update!(binding_finalized_at: Time.current)
    old_staff_email = OperatorEmail.create!(
      staff: @staff,
      raw_address: staff_email_address,
      confirm_policy: true,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    original_types =
      [
        [ClientEmail, "address", "app"], [ClientTelephone, "number", "app"],
        [OperatorEmail, "address", "org"], [OperatorTelephone, "number", "org"],
      ].map { |model, column, realm| [model, column, realm, model.type_for_attribute(column)] }
    original_environment = {}
    rotated_providers =
      %w(app org).index_with do |realm|
        prefix = realm.upcase
        current_name = "#{prefix}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
        previous_name = "#{prefix}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS"
        current = ENV.fetch(current_name)
        previous_json = ENV[previous_name]
        original_environment[current_name] = current
        original_environment[previous_name] = previous_json
        previous = previous_json.nil? ? [] : JSON.parse(previous_json)
        ENV[current_name] = SecureRandom.hex(32)
        ENV[previous_name] = JSON.generate(previous + [current])
        RealmIdentifierEncryptionKeyProvider.key_provider(realm: realm)
      end
    original_types.each do |model, column, realm, type|
      scheme = type.scheme.merge(key_provider: rotated_providers.fetch(realm))
      rotated_type = ActiveRecord::Encryption::EncryptedAttributeType.new(
        scheme: scheme, cast_type: type.cast_type, default: model.columns_hash.fetch(column).default,
      )
      model.attribute(column, rotated_type)
    end
    reencrypt_result = IdentifierEncryptionReencrypt.new.call

    assert_operator reencrypt_result.user_emails_reencrypted, :>=, 1
    assert_operator reencrypt_result.user_telephones_reencrypted, :>=, 1
    assert_operator reencrypt_result.staff_emails_reencrypted, :>=, 1

    assert_equal app_email_address, old_app_email.reload.address
    assert_equal app_telephone_number, old_app_telephone.reload.number
    assert_equal staff_email_address, old_staff_email.reload.address

    [
      [old_app_email, "address", "app"], [old_app_telephone, "number", "app"],
      [old_staff_email, "address", "org"],
    ].each do |record, column, realm|
      assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
        ActiveRecord::Encryption.encryptor.decrypt(
          record.read_attribute_before_type_cast(column), key_provider: original_realm_providers.fetch(realm),
        )
      end
    end

    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(app_host)
    https!
    headers = as_user_headers(@user, host: app_host)

    get(base_app_identity_emails_path(ri: "us"), headers:)

    assert_response :success
    assert_includes inertia_props.fetch("emails").map { |email| email.fetch("address") }, app_email_address
  ensure
    original_types&.each { |model, column, _, type| model.attribute(column, type) }
    original_environment&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  private
end
