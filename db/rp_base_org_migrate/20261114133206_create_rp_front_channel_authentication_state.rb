# frozen_string_literal: true

class CreateRpFrontChannelAuthenticationState < ActiveRecord::Migration[8.2]
  def change
    create_table(:rp_consumed_id_token_jtis) do |t|
      t.string(:jti_digest, null: false, limit: 64)
      t.datetime(:expires_at, null: false, precision: 6)
      t.timestamps(null: false)
    end
    add_index(:rp_consumed_id_token_jtis, :jti_digest, unique: true, name: "idx_rp_consumed_id_token_jtis_digest")
    add_index(:rp_consumed_id_token_jtis, :expires_at, name: "idx_rp_consumed_id_token_jtis_expires_at")
    add_check_constraint(:rp_consumed_id_token_jtis, "jti_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_rp_consumed_id_token_jtis_digest")

    create_table(:rp_session_authentication_evidences) do |t|
      t.references(:rp_session, null: false, index: false)
      t.string(:acr, null: false, limit: 255)
      t.jsonb(:amr, null: false)
      t.bigint(:auth_time, null: false)
      t.string(:id_token_jti_digest, null: false, limit: 64)
      t.string(:authentication_context, null: false, limit: 16, default: "normal")
      t.timestamps(null: false)
    end
    add_index(:rp_session_authentication_evidences, :rp_session_id, unique: true,
      name: "idx_rp_session_authentication_evidences_session")
    add_foreign_key(:rp_session_authentication_evidences, :rp_sessions,
      column: :rp_session_id, name: "fk_rp_session_authentication_evidence_session",
      on_delete: :cascade, validate: false)
    add_check_constraint(:rp_session_authentication_evidences,
      "CASE WHEN jsonb_typeof(amr) = 'array' THEN jsonb_array_length(amr) > 0 ELSE false END",
      name: "chk_rp_session_authentication_evidence_amr")
    add_check_constraint(:rp_session_authentication_evidences, "id_token_jti_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_rp_session_authentication_evidence_jti_digest")
    add_check_constraint(:rp_session_authentication_evidences,
      "authentication_context = 'normal'", name: "chk_rp_session_authentication_evidence_context")
    add_check_constraint(:rp_session_authentication_evidences,
      "auth_time > 0", name: "chk_rp_session_authentication_evidence_auth_time")
  end
end
