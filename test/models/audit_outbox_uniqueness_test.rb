# frozen_string_literal: true

require "test_helper"

class AuditOutboxUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "each audit source rejects duplicate event identity in validation and PostgreSQL" do
    now = Time.current.change(usec: 0)
    cases = [
      [ClientPasskeyAuditOutbox, :event_uuid, {
        event_type: "passkey.removed", surface: "app", external_id: SecureRandom.uuid, occurred_at: now,
      },],
      [OperatorPasskeyAuditOutbox, :event_uuid, {
        event_type: "passkey.removed", surface: "org", external_id: SecureRandom.uuid, occurred_at: now,
      },],
      [ClientContactAuditOutbox, :event_uuid, {
        contact_kind: "email",
        event_name: "finalized",
        owner_ref: "owner",
        contact_ref: "contact",
        operation_ref: SecureRandom.uuid,
        occurred_at: now,
      },],
      [ClientSocialAuditOutbox, :event_uuid, {
        operation_ref: SecureRandom.uuid,
        owner_ref: "owner",
        identity_ref: "identity",
        provider: "google",
        provider_subject_digest: "a" * 64,
        event_name: "linked",
        occurred_at: now,
      },],
      [ClientSecretAuditOutbox, :event_id, {
        event_name: "secret.created", client_ref: "owner", operation_ref: SecureRandom.uuid, occurred_at: now,
      },],
    ]

    cases.each do |model, key, attributes|
      original = model.create!(**attributes, key => SecureRandom.uuid)
      duplicate = model.new(**attributes, key => original[key])

      assert_not duplicate.valid?, model.name
      assert duplicate.errors.of_kind?(key, :taken)
      assert_predicate model.create!(**attributes, key => SecureRandom.uuid), :persisted?
      original.update!(updated_at: now + 1.second)

      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.insert_all!([original.attributes.except("id")])
        end
      end
      assert_equal 1, model.where(key => original[key]).count
    end
  end

  test "registration operations conflict across both registration events but remain realm local" do
    now = Time.current.change(usec: 0)
    [[ClientPasskeyAuditOutbox, "app"], [OperatorPasskeyAuditOutbox, "org"]].each do |model, surface|
      original = model.create!(
        event_uuid: SecureRandom.uuid, event_type: "passkey.registered.signup", surface: surface,
        external_id: SecureRandom.uuid, operation_ref: "same-registration", occurred_at: now,
      )
      duplicate = model.new(
        event_uuid: SecureRandom.uuid, event_type: "passkey.registered.settings", surface: surface,
        external_id: SecureRandom.uuid, operation_ref: original.operation_ref, occurred_at: now,
      )

      assert_not duplicate.valid?, surface
      assert duplicate.errors.of_kind?(:operation_ref, :taken)
      assert_predicate model.create!(
        event_uuid: SecureRandom.uuid, event_type: "passkey.registered.settings", surface: surface,
        external_id: SecureRandom.uuid, operation_ref: "different-registration", occurred_at: now,
      ), :persisted?
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.insert_all!(
            [
              original.attributes.except("id").merge(
                "event_uuid" => SecureRandom.uuid,
                "event_type" => "passkey.registered.settings",
              ),
            ],
          )
        end
      end
      assert_equal 1, model.where(operation_ref: original.operation_ref).count
    end
  end

  test "nil and empty registration references repeat but whitespace remains an indexed value" do
    now = Time.current.change(usec: 0)
    [[ClientPasskeyAuditOutbox, "app"], [OperatorPasskeyAuditOutbox, "org"]].each do |model, surface|
      [nil, ""].each do |reference|
        2.times do
          assert_predicate model.create!(
            event_uuid: SecureRandom.uuid, event_type: "passkey.registered.settings", surface: surface,
            external_id: SecureRandom.uuid, operation_ref: reference, occurred_at: now,
          ), :persisted?
        end
      end
      model.create!(
        event_uuid: SecureRandom.uuid, event_type: "passkey.registered.settings", surface: surface,
        external_id: SecureRandom.uuid, operation_ref: " ", occurred_at: now,
      )
      duplicate = model.new(
        event_uuid: SecureRandom.uuid, event_type: "passkey.registered.signup", surface: surface,
        external_id: SecureRandom.uuid, operation_ref: " ", occurred_at: now,
      )

      assert_not duplicate.valid?, surface
      assert duplicate.errors.of_kind?(:operation_ref, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) {
          model.insert_all!([duplicate.attributes.except("id").merge("created_at" => now, "updated_at" => now)])
        }
      end
    end
  end

  test "ordinary lifecycle events may share operation references with registrations and each other" do
    now = Time.current.change(usec: 0)
    [[ClientPasskeyAuditOutbox, "app"], [OperatorPasskeyAuditOutbox, "org"]].each do |model, surface|
      %w(passkey.registered.settings passkey.removed passkey.revoked passkey.removed).each do |type|
        assert_predicate model.create!(
          event_uuid: SecureRandom.uuid, event_type: type, surface: surface,
          external_id: SecureRandom.uuid, operation_ref: "shared-operation", occurred_at: now,
        ), :persisted?
      end
      assert_equal 4, model.where(operation_ref: "shared-operation").count
    end
  end

  test "a repeated registration operation rolls back its new credential on both realms" do
    [[Client, ClientPasskey, ClientPasskeyAuditOutbox, "app"],
     [Operator, OperatorPasskey, OperatorPasskeyAuditOutbox,
      "org",],].each do |owner_class, passkey_class, outbox_class, realm|
      owner = owner_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      audit = { event_type: "passkey.registered.settings", surface: realm, operation_ref: "registration-once" }
      first = PasskeyRegistrationOperation.call!(
        actor: owner, passkey_class: passkey_class,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "public-key" }, audit: audit,
      )
      second_id = SecureRandom.uuid
      assert_no_difference [-> { passkey_class.count }, -> { outbox_class.count }] do
        error =
          assert_raises(ActiveRecord::RecordInvalid) do
            PasskeyRegistrationOperation.call!(
              actor: owner, passkey_class: passkey_class,
              attributes: { webauthn_id: second_id, public_key: "other-key" }, audit: audit,
            )
          end

        assert_instance_of outbox_class, error.record
        assert error.record.errors.of_kind?(:operation_ref, :taken)
      end
      assert_not passkey_class.exists?(webauthn_id: second_id)
      assert_predicate first.reload, :persisted?
      assert_equal 1, outbox_class.where(operation_ref: "registration-once").count
    end
  end
end
