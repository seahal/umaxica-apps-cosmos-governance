# frozen_string_literal: true

# The front-channel Base profile no longer creates code/PKCE callback state. The old table had no
# live application caller; dropping it also removes stored encrypted code verifiers. Existing
# pending Code-flow callbacks are intentionally invalidated. Rollback recreates the empty shape.
class DropRpBaseOrgCallbackStates < ActiveRecord::Migration[8.2]
  def up
    drop_table(:rp_callback_states)
  end

  def down
    create_table(:rp_callback_states) do |t|
      t.binary(:state_digest, null: false, limit: 32)
      t.binary(:browser_binding_digest, null: false, limit: 32)
      t.binary(:nonce_digest, null: false, limit: 32)
      t.string(:pkce_challenge, null: false, limit: 128)
      t.text(:pkce_verifier_ciphertext, null: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.datetime(:expires_at, null: false)
      t.datetime(:consumed_at)
      t.timestamps
    end
    add_index(:rp_callback_states, :state_digest, unique: true, name: "idx_rp_base_org_callback_states_state")
    add_index(:rp_callback_states, :expires_at, name: "idx_rp_base_org_callback_states_expiry")
    add_check_constraint(
      :rp_callback_states, "realm = 'org' AND client_id = 'base-org-ww'",
      name: "chk_rp_base_org_callback_states_cell",
    )
  end
end
