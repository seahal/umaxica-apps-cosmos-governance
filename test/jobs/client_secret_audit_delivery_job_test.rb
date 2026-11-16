# frozen_string_literal: true

require "test_helper"

class ClientSecretAuditDeliveryJobTest < ActiveSupport::TestCase
  # These cases reference only the Client and Secret-credential fixtures; keep other realms out.
  self.fixture_table_names = %w(clients client_secret_credentials)

  setup do
    @security_policy = ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
  end

  test "a conflicting Secret audit does not starve later pages" do
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    poison, later =
      ClientSecretAuditOutbox.transaction do
        [ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id, operation_ref: SecureRandom.uuid,
          occurred_at: Client.database_now, event_name: "secret.issuance_started", reason: "manual", item_count: 1,
        ), ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id, operation_ref: SecureRandom.uuid,
          occurred_at: Client.database_now, event_name: "secret.issuance_started", reason: "manual", item_count: 1,
        ),]
      end
    Chronicle.create!(
      event_uuid: poison.event_id, action: poison.event_name, result: "succeeded", reason: "flow_canceled",
      actor_type: "Client", actor_id: client.id, subject_type: "Client", subject_id: client.id,
      chronicle_retention_policy: @security_policy, occurred_at: poison.occurred_at,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: @security_policy, occurred_at: poison.occurred_at),
      request_id: poison.operation_ref, metadata: {
        "client_ref" => client.public_id, "actor_public_ref" => client.public_id, "item_count" => 1,
      }, changeset: {},
    )

    assert_raises(ArgumentError) { ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 60) }
    assert_nil poison.reload.delivered_at
    assert_predicate later.reload.delivered_at, :present?
    assert_equal 1, Chronicle.where(event_uuid: later.event_id).count
  end

  test "an existing Chronicle UUID with different immutable facts is not accepted as delivery" do
    policy = @security_policy
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.issuance_started", reason: "manual", item_count: 1,
        )
      end
    Chronicle.create!(
      event_uuid: event.event_id, action: event.event_name, result: "succeeded", reason: "flow_canceled",
      actor_type: "Client", actor_id: client.id, subject_type: "Client", subject_id: client.id,
      chronicle_retention_policy: policy, occurred_at: event.occurred_at,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
      request_id: event.operation_ref, metadata: {
        "client_ref" => client.public_id, "actor_public_ref" => client.public_id, "item_count" => 1,
      }, changeset: {},
    )
    assert_raises(ArgumentError) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    assert_nil event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
  end

  test "Chronicle commit survives failed source acknowledgment and rescan deduplicates the event" do
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event =
      ClientSecretAuditOutbox.transaction do
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: client.public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.issuance_started",
          reason: "manual", item_count: 1,
        )
      end
    # Roll back only the Source acknowledgement; Chronicle uses its own connection.
    ClientSecretAuditOutbox.transaction(requires_new: true) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

      assert event.reload.delivered_at
      assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
      raise ActiveRecord::Rollback
    end

    assert_nil event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
    assert_no_difference("Chronicle.count") do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    assert event.reload.delivered_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_id).count
  end

  test "source events reach Chronicle once and can be rescanned without queue enqueue" do
    # Source outboxes outlive fixture replacement; deliver earlier durable work first.
    while ClientSecretAuditOutbox.exists?(delivered_at: nil)
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)
    end
    client = clients(:one)
    context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
    event = nil
    ClientSecretAuditOutbox.transaction do
      event = ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: client.public_id, credential_ref: client_secret_credentials(:one).public_id,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.renamed",
      )
    end
    assert_difference("Chronicle.count", 1) do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 60)
    end
    assert event.reload.delivered_at
    persisted = Chronicle.find_by!(event_uuid: event.event_id)

    assert_equal "secret.renamed", persisted.action
    assert_equal event.client_ref, persisted.metadata.fetch("client_ref")
    assert_equal event.credential_ref, persisted.metadata.fetch("credential_ref")
    assert_equal event.operation_ref, persisted.request_id
    assert_no_difference("Chronicle.count") {
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 1, retention_seconds: 60)
    }
    assert_nil persisted.metadata["name"]
    assert_nil persisted.metadata["password_digest"]
  end
end
