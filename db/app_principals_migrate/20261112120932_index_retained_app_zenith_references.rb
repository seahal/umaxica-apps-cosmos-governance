# frozen_string_literal: true

class IndexRetainedAppZenithReferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:client_preferences, :status_id, algorithm: :concurrently)
    add_index(:client_retention_holds, :status_id, algorithm: :concurrently)
    add_index(:client_privacy_requests, :status_id, algorithm: :concurrently)
    add_index(:client_registration_completions, :method_id, algorithm: :concurrently)
  end

  def down
    remove_index(:client_registration_completions, :method_id, algorithm: :concurrently)
    remove_index(:client_privacy_requests, :status_id, algorithm: :concurrently)
    remove_index(:client_retention_holds, :status_id, algorithm: :concurrently)
    remove_index(:client_preferences, :status_id, algorithm: :concurrently)
  end
end
