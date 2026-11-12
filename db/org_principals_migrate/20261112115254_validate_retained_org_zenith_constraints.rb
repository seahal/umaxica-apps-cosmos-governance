# frozen_string_literal: true

class ValidateRetainedOrgZenithConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:operators, name: "chk_operators_withdrawal_order")
    validate_foreign_key(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
    validate_foreign_key(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
    validate_foreign_key(:agents, name: "fk_rails_00d34c9052")
    validate_foreign_key(:agent_memberships, name: "fk_rails_05081537eb")
    validate_foreign_key(:agent_memberships, name: "fk_rails_1a95fbbc46")
    validate_foreign_key(:agent_memberships, name: "fk_rails_27ba6b71fd")
    validate_foreign_key(:operator_workspace_account_memberships, name: "fk_rails_46775ba732")
    validate_foreign_key(:agent_memberships, name: "fk_rails_598d6fdb3c")
    validate_foreign_key(:operator_lifecycle_requests, name: "fk_rails_be7647e7b5")
    validate_foreign_key(:agent_memberships, name: "fk_rails_ed6c87c035")
    validate_foreign_key(:agent_memberships, name: "fk_rails_feb3a1d9a5")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Keep existing constraints validated when rolling application code back"
  end
end
