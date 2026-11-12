# frozen_string_literal: true

require "test_helper"

class AuthenticatorMetadataTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "absent metadata explicitly records unknown backup observations" do
    assert_equal({ backup_eligibility: "unknown", backup_observation: "unknown" }, Webauthn::AuthenticatorMetadata.permit(nil))
    assert_equal({ backup_eligibility: "unknown", backup_observation: "unknown" }, Webauthn::AuthenticatorMetadata.permit({}))
  end

  test "true and false retain their distinct observed meanings" do
    metadata = Webauthn::AuthenticatorMetadata.permit(backup_eligible: true, backup_state: false)

    assert_equal "eligible", metadata.fetch(:backup_eligibility)
    assert_equal "not_backed_up", metadata.fetch(:backup_observation)
    assert_not metadata.key?(:backup_eligible)
    assert_not metadata.key?(:backup_state)
  end

  test "false eligibility and true observation are independently preserved" do
    metadata = Webauthn::AuthenticatorMetadata.permit("backup_eligible" => false, "backup_state" => true)

    assert_equal "ineligible", metadata.fetch(:backup_eligibility)
    assert_equal "backed_up", metadata.fetch(:backup_observation)
  end

  test "partial metadata leaves the missing observation unknown" do
    metadata = Webauthn::AuthenticatorMetadata.permit(backup_eligible: true)

    assert_equal "eligible", metadata.fetch(:backup_eligibility)
    assert_equal "unknown", metadata.fetch(:backup_observation)
  end

  test "nil and malformed optional values never become affirmative observations" do
    [nil, "false", "true", 0, 1, [], {}].each do |value|
      metadata = Webauthn::AuthenticatorMetadata.permit(backup_eligible: value, backup_state: value)

      assert_equal "unknown", metadata.fetch(:backup_eligibility)
      assert_equal "unknown", metadata.fetch(:backup_observation)
    end
  end

  test "metadata whitelist preserves display fields and rejects persisted enum injection" do
    metadata = Webauthn::AuthenticatorMetadata.permit(
      provider_name: "Example", backup_eligibility: "eligible", backup_observation: "backed_up", user_id: 7,
    )

    assert_equal "Example", metadata.fetch(:provider_name)
    assert_equal "unknown", metadata.fetch(:backup_eligibility)
    assert_equal "unknown", metadata.fetch(:backup_observation)
    assert_not metadata.key?(:user_id)
  end
end
