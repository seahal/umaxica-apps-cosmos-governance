# frozen_string_literal: true

class ExpandRegistrationCompletionIdentifierWidth < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    connection.transaction do
      remove_foreign_key(:client_registration_completions, name: "fk_rails_cc76c55eef")
      # The owner approved these two numeric rewrites with values and constraints preserved.
      safety_assured do
        change_column(:client_registration_completion_methods, :id, :bigint, null: false)
        change_column(:client_registration_completions, :method_id, :bigint, null: false)
      end
      add_foreign_key(
        :client_registration_completions, :client_registration_completion_methods,
        column: :method_id, name: "fk_rails_cc76c55eef", on_delete: :restrict, validate: false,
      )
    end
    validate_foreign_key(:client_registration_completions, name: "fk_rails_cc76c55eef")
  end

  def down
    connection.transaction do
      remove_foreign_key(:client_registration_completions, name: "fk_rails_cc76c55eef")
      # The retained fixed-ID CHECK and FK keep every value in the reversible range 1..4.
      safety_assured do
        change_column(:client_registration_completion_methods, :id, :integer, limit: 2, null: false)
        change_column(:client_registration_completions, :method_id, :integer, limit: 2, null: false)
      end
      add_foreign_key(
        :client_registration_completions, :client_registration_completion_methods,
        column: :method_id, name: "fk_rails_cc76c55eef", on_delete: :restrict, validate: false,
      )
    end
    validate_foreign_key(:client_registration_completions, name: "fk_rails_cc76c55eef")
  end
end
