# frozen_string_literal: true

class ValidateRpFrontChannelAuthenticationEvidenceForeignKey < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_foreign_key(:rp_session_authentication_evidences, name: "fk_rp_session_authentication_evidence_session")
  end

  def down
    remove_foreign_key(:rp_session_authentication_evidences, name: "fk_rp_session_authentication_evidence_session")
    add_foreign_key(
      :rp_session_authentication_evidences, :rp_sessions,
      column: :rp_session_id, name: "fk_rp_session_authentication_evidence_session",
      on_delete: :cascade, validate: false,
    )
  end
end
