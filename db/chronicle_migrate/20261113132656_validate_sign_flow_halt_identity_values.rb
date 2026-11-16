# frozen_string_literal: true

class ValidateSignFlowHaltIdentityValues < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CHECK_NAME = "chk_operator_chronicles_sign_flow_halted_identity"
  CHECK_EXPRESSION =
    "event_id <> 18 OR " \
    "(context ->> 'transaction_public_id' IS NOT NULL AND " \
    "context ->> 'halt_generation' IS NOT NULL)"

  def up
    validate_check_constraint(
      :operator_chronicles,
      name: CHECK_NAME,
    )
  end

  def down
    transaction do
      remove_check_constraint(:operator_chronicles, name: CHECK_NAME)
      add_check_constraint(
        :operator_chronicles,
        CHECK_EXPRESSION,
        name: CHECK_NAME,
        validate: false,
      )
    end
  end
end
