# frozen_string_literal: true

require "test_helper"

class ClientEnforcementRecoveryCeremonyOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a recovery ceremony stays attached to its owner and prevents direct deletion" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    ceremony = ClientEnforcementRecoveryCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)

    assert_includes client.enforcement_recovery_ceremonies, ceremony
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Client.transaction(requires_new: true) { Client.where(id: client.id).delete_all }
    end
    assert_predicate ceremony.reload, :persisted?
  end
end
