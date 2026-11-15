# frozen_string_literal: true

# Governance-owned pending registration (adr/sign-up-finalization-in-auth.md, Cosmos split amendment).
class CreateClientRegistrations < ActiveRecord::Migration[8.2]
  public

  def up
    create_table(:client_registration_statuses)
    add_check_constraint(
      :client_registration_statuses, "id BETWEEN 1 AND 5",
      validate: false, name: "chk_client_registration_statuses_id",
    )

    create_table(:client_registrations) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.bigint(:status_id, null: false)
      t.bigint(:method_id, null: false)
      t.string(:identifier_digest, limit: 64, null: false)
      t.text(:identifier, null: false)
      t.text(:birthdate, null: false)
      t.string(:webauthn_user_handle, limit: 43, null: false)
      t.string(:access_ceremony_digest, limit: 43, null: false)
      t.string(:browser_secret_digest, limit: 64, null: false)
      t.timestamptz(:deadline_at, null: false)
      t.timestamptz(:status_changed_at, null: false)
      t.timestamptz(:purge_after, null: false)
      t.timestamps(null: false)
    end
    add_index(:client_registrations, :public_id, unique: true)
    add_index(:client_registrations, :webauthn_user_handle, unique: true)
    add_index(
      :client_registrations, %i(method_id identifier_digest), unique: true, where: "status_id = 1",
                                                             name: "index_client_registrations_pending_identifier",
    )
    add_index(
      :client_registrations, :browser_secret_digest, unique: true, where: "status_id = 1",
                                                     name: "index_client_registrations_pending_browser",
    )
    add_index(:client_registrations, %i(status_id deadline_at), name: "index_client_registrations_on_status_deadline")
    add_index(:client_registrations, %i(status_id purge_after), name: "index_client_registrations_on_status_purge")
    add_foreign_key(
      :client_registrations, :client_registration_statuses,
      column: :status_id, on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :client_registrations, :client_registration_completion_methods,
      column: :method_id, on_delete: :restrict, validate: false,
    )
    add_check_constraint(
      :client_registrations, "char_length(public_id) = 21",
      validate: false, name: "chk_client_registrations_public_id",
    )
    add_check_constraint(
      :client_registrations, "char_length(webauthn_user_handle) = 43",
      validate: false, name: "chk_client_registrations_user_handle",
    )
    add_check_constraint(
      :client_registrations, "char_length(access_ceremony_digest) = 43",
      validate: false, name: "chk_client_registrations_ceremony_digest",
    )
    add_check_constraint(
      :client_registrations, "char_length(browser_secret_digest) = 64",
      validate: false, name: "chk_client_registrations_browser_digest",
    )
    add_check_constraint(
      :client_registrations, "char_length(identifier_digest) = 64",
      validate: false, name: "chk_client_registrations_identifier_digest",
    )
    add_check_constraint(
      :client_registrations,
      "isfinite(deadline_at) AND isfinite(status_changed_at) AND isfinite(purge_after)",
      validate: false, name: "chk_client_registrations_finite_times",
    )

    create_table(:client_registration_handoff_receipts) do |t|
      t.string(:jti_digest, limit: 64, null: false)
      t.string(:kind, limit: 16, null: false)
      t.timestamptz(:expires_at, null: false)
      t.timestamptz(:created_at, null: false)
    end
    add_index(:client_registration_handoff_receipts, :jti_digest, unique: true)
    add_index(:client_registration_handoff_receipts, :expires_at)
    add_check_constraint(
      :client_registration_handoff_receipts, "kind IN ('start', 'credential', 'cancellation')",
      validate: false, name: "chk_client_registration_handoff_receipts_kind",
    )
    add_check_constraint(
      :client_registration_handoff_receipts, "char_length(jti_digest) = 64",
      validate: false, name: "chk_client_registration_handoff_receipts_jti_digest",
    )

    create_table(:client_registration_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:event_type, limit: 32, null: false)
      t.jsonb(:metadata, null: false, default: {})
      t.timestamptz(:occurred_at, null: false)
      t.boolean(:delivered, null: false, default: false)
      t.timestamptz(:created_at, null: false)
    end
    add_index(:client_registration_audit_outboxes, :event_uuid, unique: true)
    add_index(
      :client_registration_audit_outboxes, :id, where: "delivered = false",
                                                name: "index_client_registration_audit_outboxes_undelivered",
    )
    add_check_constraint(
      :client_registration_audit_outboxes,
      "event_type IN ('registration.started', 'registration.completed', 'registration.cancelled', " \
      "'registration.expired', 'registration.halted', 'registration.refused')",
      validate: false, name: "chk_client_registration_audit_outboxes_event_type",
    )
  end

  def down
    if connection.select_value("SELECT EXISTS (SELECT 1 FROM client_registrations)") ||
        connection.select_value("SELECT EXISTS (SELECT 1 FROM client_registration_audit_outboxes)")
      raise ActiveRecord::IrreversibleMigration, "Registration rows and audit records require an approved recovery plan"
    end

    drop_table(:client_registration_audit_outboxes)
    drop_table(:client_registration_handoff_receipts)
    drop_table(:client_registrations)
    drop_table(:client_registration_statuses)
  end
end
