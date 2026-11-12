# frozen_string_literal: true

class IndexOrgOwnershipTransferSourceActors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :bureau_ownership_transfer_requests, :source_operator_id,
      name: "idx_bureau_transfers_source_operator", algorithm: :concurrently,
    )
    add_index(
      :agent_ownership_transfer_requests, :source_operator_id,
      name: "idx_agent_transfers_source_operator", algorithm: :concurrently,
    )
  end

  def down
    remove_index(
      :agent_ownership_transfer_requests,
      name: "idx_agent_transfers_source_operator", algorithm: :concurrently,
    )
    remove_index(
      :bureau_ownership_transfer_requests,
      name: "idx_bureau_transfers_source_operator", algorithm: :concurrently,
    )
  end
end
