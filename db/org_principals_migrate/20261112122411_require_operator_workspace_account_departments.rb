# frozen_string_literal: true

class RequireOperatorWorkspaceAccountDepartments < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    connection.transaction do
      # The owner approved scans only on isolated development/test data; existing NULLs abort
      # this transaction without a backfill or any change to the original foreign keys.
      safety_assured do
        change_column_null(:operator_workspace_accounts, :department_id, false)
      end
      remove_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_department_id")
      add_foreign_key(
        :operator_workspace_accounts, :departments,
        column: :department_id, name: "fk_operator_workspace_accounts_on_department_id", on_delete: :restrict, validate: false,
      )
    end
    validate_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_department_id")
  end

  def down
    connection.transaction do
      change_column_null(:operator_workspace_accounts, :department_id, true)
      remove_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_department_id")
      add_foreign_key(
        :operator_workspace_accounts, :departments,
        column: :department_id, name: "fk_operator_workspace_accounts_on_department_id", on_delete: :nullify, validate: false,
      )
    end
    validate_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_department_id")
  end
end
