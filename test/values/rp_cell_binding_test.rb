# frozen_string_literal: true

require "test_helper"

class RpCellBindingTest < ActiveSupport::TestCase
  test "the public connection catalog and client lookup share fixed bindings" do
    assert_equal %w(rp_base_app rp_base_org rp_tech_org), RpCellBinding.connections.sort
    assert_equal RpCellBinding::CELLS.keys, RpCellBinding.connections
    RpCellBinding::CELLS.each do |connection, cell|
      assert_equal cell, RpCellBinding.fetch(connection)
      assert_equal cell, RpCellBinding.for_client(cell.client_id)
    end
  end

  test "unknown connections and client IDs are rejected" do
    [nil, "", 0, "missing"].each do |value|
      assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.fetch(value) }
      assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client(value) }
    end
  end
  test "foreign connections and client IDs cannot select a Governance store" do
    %w(rp_core_app rp_warp_app rp_palm_app rp_core_org rp_warp_org rp_edit_org).each do |connection|
      assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.fetch(connection) }
    end
    %w(core-app-jp warp-app-jp palm-app-jp core-org-jp warp-org-jp edit-org-ww).each do |client_id|
      assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client(client_id) }
    end
  end
end
