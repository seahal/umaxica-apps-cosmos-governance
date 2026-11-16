# frozen_string_literal: true

class RequireClientResourceOwners < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    connection.transaction do
      # The owner approved scans only on isolated development/test data; existing NULLs abort
      # this transaction without a backfill or any change to the original foreign keys.
      safety_assured do
        change_column_null(:client_profiles, :user_id, false)
        change_column_null(:members, :user_id, false)
      end
      remove_foreign_key(:client_profiles, name: "fk_client_profiles_on_user_id")
      add_foreign_key(
        :client_profiles, :clients,
        column: :user_id, name: "fk_client_profiles_on_user_id", on_delete: :restrict, validate: false,
      )
      remove_foreign_key(:members, name: "fk_rails_2e88fb7ce9")
      add_foreign_key(
        :members, :clients,
        column: :user_id, name: "fk_rails_2e88fb7ce9", on_delete: :restrict, validate: false,
      )
    end
    validate_foreign_key(:client_profiles, name: "fk_client_profiles_on_user_id")
    validate_foreign_key(:members, name: "fk_rails_2e88fb7ce9")
  end

  def down
    connection.transaction do
      change_column_null(:client_profiles, :user_id, true)
      change_column_null(:members, :user_id, true)
      remove_foreign_key(:client_profiles, name: "fk_client_profiles_on_user_id")
      add_foreign_key(
        :client_profiles, :clients,
        column: :user_id, name: "fk_client_profiles_on_user_id", on_delete: :nullify, validate: false,
      )
      remove_foreign_key(:members, name: "fk_rails_2e88fb7ce9")
      add_foreign_key(
        :members, :clients,
        column: :user_id, name: "fk_rails_2e88fb7ce9", on_delete: :nullify, validate: false,
      )
    end
    validate_foreign_key(:client_profiles, name: "fk_client_profiles_on_user_id")
    validate_foreign_key(:members, name: "fk_rails_2e88fb7ce9")
  end
end
