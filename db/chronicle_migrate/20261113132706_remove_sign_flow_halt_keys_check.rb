# frozen_string_literal: true

class RemoveSignFlowHaltKeysCheck < ActiveRecord::Migration[8.2]
  CHECK_NAME = "chk_operator_chronicles_sign_flow_halted_keys"
  SIGN_FLOW_HALTED = 18

  def up
    remove_check_constraint(:operator_chronicles, name: CHECK_NAME)
  end

  def down
    add_check_constraint(
      :operator_chronicles,
      "event_id <> #{SIGN_FLOW_HALTED} OR " \
      "(context ? 'transaction_public_id' AND context ? 'halt_generation')",
      name: CHECK_NAME,
    )
  end
end
