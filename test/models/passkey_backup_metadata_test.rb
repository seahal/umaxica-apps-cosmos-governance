# frozen_string_literal: true

require "test_helper"

class PasskeyBackupMetadataTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "backup metadata has explicit defaults and validates all enum partitions on both surfaces" do
    [ClientPasskey, OperatorPasskey].each do |model|
      credential = model.new

      assert_equal "unknown", credential.backup_eligibility
      assert_equal "unknown", credential.backup_observation

      %w(unknown ineligible eligible).each do |state|
        credential.backup_eligibility = state
        credential.valid?

        assert_not credential.errors.include?(:backup_eligibility)
      end
      %w(unknown not_backed_up backed_up).each do |state|
        credential.backup_observation = state
        credential.valid?

        assert_not credential.errors.include?(:backup_observation)
      end
      [nil, "", "unrecognized"].each do |state|
        credential.backup_eligibility = state
        credential.backup_observation = state
        credential.valid?

        assert credential.errors.of_kind?(:backup_eligibility, :inclusion)
        assert credential.errors.of_kind?(:backup_observation, :inclusion)
      end
    end
  end

  test "PostgreSQL rejects missing and invalid explicit backup metadata when validation is bypassed" do
    [[Client, ClientPasskey, :user], [Operator, OperatorPasskey, :staff]].each do |actor_class, model, owner|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      credential = model.create!(owner => actor, :webauthn_id => SecureRandom.uuid, :public_key => "metadata-test-key")

      [:backup_eligibility, :backup_observation].each do |column|
        assert_raises(ActiveRecord::NotNullViolation) do
          model.transaction(requires_new: true) { model.where(id: credential.id).update_all(column => nil) }
        end
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { model.where(id: credential.id).update_all(column => "invalid") }
        end
      end
      assert_equal "unknown", credential.reload.backup_eligibility
      assert_equal "unknown", credential.backup_observation
    end
  end
  test "registration persists optional wire observations independently for both account surfaces" do
    [[Client, ClientPasskey, "app"], [Operator, OperatorPasskey, "org"]].each do |actor_class, model, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      [
        [nil, "unknown", "unknown"],
        [{ backup_eligible: false, backup_state: false }, "ineligible", "not_backed_up"],
        [{ backup_eligible: true, backup_state: true }, "eligible", "backed_up"],
        [{ backup_eligible: true }, "eligible", "unknown"],
      ].each do |wire, eligibility, observation|
        credential = PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: model,
          attributes: {
            webauthn_id: SecureRandom.uuid,
            public_key: "registration-metadata-key",
            **Webauthn::AuthenticatorMetadata.permit(wire),
          },
          audit: { event_type: "passkey.registered.settings", surface: surface },
        )

        assert_equal eligibility, credential.reload.backup_eligibility
        assert_equal observation, credential.backup_observation
      end
    end
  end
end
