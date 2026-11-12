# frozen_string_literal: true

class IndexAppOwnershipTransferSourceActors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :enterprise_ownership_transfer_requests, :source_client_id,
      name: "idx_enterprise_transfers_source_client", algorithm: :concurrently,
    )
    add_index(
      :client_persona_ownership_transfer_requests, :source_client_id,
      name: "idx_persona_transfers_source_client", algorithm: :concurrently,
    )
  end

  def down
    remove_index(
      :client_persona_ownership_transfer_requests,
      name: "idx_persona_transfers_source_client", algorithm: :concurrently,
    )
    remove_index(
      :enterprise_ownership_transfer_requests,
      name: "idx_enterprise_transfers_source_client", algorithm: :concurrently,
    )
  end
end
