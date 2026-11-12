# frozen_string_literal: true

require "test_helper"

class ClientChronicleEventUuidUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "event UUID is unique while absent legacy UUIDs remain valid" do
    ClientChronicleEvent.ensure_defaults!
    ClientChronicleLevel.ensure_defaults!
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    attributes = {
      actor: actor,
      subject_type: "Client",
      subject_id: "123",
      occurred_at: Time.current,
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      level_id: ClientChronicleLevel::INFO,
    }
    original = ClientChronicle.create!(**attributes, event_uuid: SecureRandom.uuid)
    duplicate = ClientChronicle.new(**attributes, event_uuid: original.event_uuid)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:event_uuid, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientChronicle.transaction(requires_new: true) do
        ClientChronicle.insert_all!([original.attributes.except("id")])
      end
    end
    assert_predicate ClientChronicle.create!(**attributes, event_uuid: nil), :persisted?
    assert_predicate ClientChronicle.create!(**attributes, event_uuid: nil), :persisted?
  end
end
