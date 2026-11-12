# frozen_string_literal: true

class IndexRetainedOrgZenithReferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:operator_preferences, :status_id, algorithm: :concurrently)
  end

  def down
    remove_index(:operator_preferences, :status_id, algorithm: :concurrently)
  end
end
