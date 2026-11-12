# frozen_string_literal: true

require "test_helper"

class PasskeyReferenceUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "registration rejects a reused internal reference on each surface without credential or audit effects" do
    [[Client, ClientPasskey, ClientPasskeyAuditOutbox, :user_id, "app"],
     [Operator, OperatorPasskey, OperatorPasskeyAuditOutbox, :staff_id,
      "org",],].each do |actor_class, model, outbox, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      reference = SecureRandom.uuid
      original = PasskeyRegistrationOperation.call!(
        actor: actor, passkey_class: model,
        attributes: { external_id: reference, webauthn_id: SecureRandom.uuid, public_key: "reference-contract-key" },
        audit: { event_type: "passkey.registered.settings", surface: surface },
      )
      credentials_before = model.where(owner_key => actor.id).count
      audit_before = outbox.count
      error =
        assert_raises(ActiveRecord::RecordInvalid) do
          PasskeyRegistrationOperation.call!(
            actor: actor, passkey_class: model,
            attributes: { external_id: reference, webauthn_id: SecureRandom.uuid, public_key: "duplicate-key" },
            audit: { event_type: "passkey.registered.settings", surface: surface },
          )
        end

      assert error.record.errors.of_kind?(:external_id, :taken)
      assert PasskeyRegistrationOperation.reference_id_conflict?(error)
      assert_not PasskeyRegistrationOperation.credential_id_conflict?(error)
      assert_equal credentials_before, model.where(owner_key => actor.id).count
      assert_equal audit_before, outbox.count
      assert_equal reference, original.reload.external_id
    end
  end

  test "reference collision classification does not turn other validation failures into identifier conflicts" do
    [[Client, ClientPasskey, "app"], [Operator, OperatorPasskey, "org"]].each do |actor_class, model, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      error =
        assert_raises(ActiveRecord::RecordInvalid) do
          PasskeyRegistrationOperation.call!(
            actor: actor, passkey_class: model,
            attributes: { webauthn_id: SecureRandom.uuid, public_key: nil },
            audit: { event_type: "passkey.registered.settings", surface: surface },
          )
        end

      assert_not PasskeyRegistrationOperation.reference_id_conflict?(error)
    end
    assert_not PasskeyRegistrationOperation.reference_id_conflict?(ActiveRecord::RecordNotUnique.new)
  end

  test "unchanged reference validation adds no identifier uniqueness probe on either surface" do
    [[Client, ClientPasskey, "app"], [Operator, OperatorPasskey, "org"]].each do |actor_class, model, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      credential = PasskeyRegistrationOperation.call!(
        actor: actor, passkey_class: model,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "unchanged-reference-key" },
        audit: { event_type: "passkey.registered.settings", surface: surface },
      )
      queries = []
      subscriber =
        ->(_name, _start, _finish, _id, payload) {
          queries << true if payload[:sql].match?(/SELECT.*(?:client|operator)_passkeys.*external_id/i)
        }

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { assert_predicate credential, :valid? }

      assert_empty queries
    end
  end
end
