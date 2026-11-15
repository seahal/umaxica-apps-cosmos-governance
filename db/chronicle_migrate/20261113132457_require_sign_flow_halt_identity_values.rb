# frozen_string_literal: true

class RequireSignFlowHaltIdentityValues < ActiveRecord::Migration[8.2]
  SIGN_FLOW_HALTED = 18
  CHECK_NAME = "chk_operator_chronicles_sign_flow_halted_identity"

  def up
    add_check_constraint(
      :operator_chronicles,
      "event_id <> #{SIGN_FLOW_HALTED} OR " \
      "(context ->> 'transaction_public_id' IS NOT NULL AND " \
      "context ->> 'halt_generation' IS NOT NULL)",
      name: CHECK_NAME,
      validate: false,
    )
  end

  def down
    remove_check_constraint(:operator_chronicles, name: CHECK_NAME)
  end
end
