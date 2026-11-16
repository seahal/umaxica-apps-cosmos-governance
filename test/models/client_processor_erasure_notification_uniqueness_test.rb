# frozen_string_literal: true

require "test_helper"

class ClientProcessorErasureNotificationUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "one notification per processor and privacy request is enforced by model and database" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    request = ClientPrivacyRequest.create!(client: client)
    original = ClientProcessorErasureNotification.create!(
      client_privacy_request: request,
      processor_key: "email_delivery",
    )
    duplicate = ClientProcessorErasureNotification.new(client_privacy_request: request, processor_key: "email_delivery")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:processor_key, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientProcessorErasureNotification.transaction(requires_new: true) do
        ClientProcessorErasureNotification.insert_all!([original.attributes.except("id")])
      end
    end
    other_client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other_request = ClientPrivacyRequest.create!(client: other_client)

    assert_predicate ClientProcessorErasureNotification.create!(
      client_privacy_request: other_request, processor_key: "email_delivery",
    ), :persisted?
  end
end
