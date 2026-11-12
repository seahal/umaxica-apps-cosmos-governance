# frozen_string_literal: true

class RetainRpBaseOrgStepUpHistoryAndRemoveRedundantIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    # Keep each replacement atomic; validate after releasing the DDL locks.
    connection.transaction do
      remove_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
      add_foreign_key(
        :rp_step_up_state_transitions, :rp_step_up_states,
        column: :owner_id, name: "fk_rails_42bc1ac3a0", on_delete: :restrict, validate: false,
      )
      remove_foreign_key(:rp_step_up_audit_outbox_attempts, name: "fk_rails_9735bc9c9b")
      add_foreign_key(
        :rp_step_up_audit_outbox_attempts, :rp_step_up_audit_outboxes,
        column: :outbox_id, name: "fk_rails_9735bc9c9b", on_delete: :restrict, validate: false,
      )
    end
    validate_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
    validate_foreign_key(:rp_step_up_audit_outbox_attempts, name: "fk_rails_9735bc9c9b")
    remove_index(
      :rp_step_up_audit_outbox_attempts,
      name: "index_rp_step_up_audit_outbox_attempts_on_outbox_id", algorithm: :concurrently,
    )
    remove_index(
      :rp_step_up_audit_outboxes,
      name: "index_rp_step_up_audit_outboxes_on_delivery_state_id", algorithm: :concurrently,
    )
  end

  def down
    add_index(
      :rp_step_up_audit_outbox_attempts, :outbox_id,
      name: "index_rp_step_up_audit_outbox_attempts_on_outbox_id", algorithm: :concurrently,
    )
    add_index(
      :rp_step_up_audit_outboxes, :delivery_state_id,
      name: "index_rp_step_up_audit_outboxes_on_delivery_state_id", algorithm: :concurrently,
    )
    connection.transaction do
      remove_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
      add_foreign_key(
        :rp_step_up_state_transitions, :rp_step_up_states,
        column: :owner_id, name: "fk_rails_42bc1ac3a0", on_delete: :cascade, validate: false,
      )
      remove_foreign_key(:rp_step_up_audit_outbox_attempts, name: "fk_rails_9735bc9c9b")
      add_foreign_key(
        :rp_step_up_audit_outbox_attempts, :rp_step_up_audit_outboxes,
        column: :outbox_id, name: "fk_rails_9735bc9c9b", on_delete: :cascade, validate: false,
      )
    end
    validate_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
    validate_foreign_key(:rp_step_up_audit_outbox_attempts, name: "fk_rails_9735bc9c9b")
  end
end
