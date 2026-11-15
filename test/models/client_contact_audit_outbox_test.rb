# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientContactAuditOutboxTest < ActiveSupport::TestCase
  test "records a committed promotional preference change inside the source transaction" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(user: actor, address: "promotion-audit@example.test", confirm_policy: "1")
    email.update!(promotional: false)

    event =
      ClientContactAuditOutbox.transaction do
        ClientContactAuditOutbox.record_preferences_changed!(actor:, email:)
      end

    assert_equal "email", event.contact_kind
    assert_equal "preferences_changed", event.event_name
    assert_equal actor.public_id, event.owner_ref
    assert_equal email.public_id, event.contact_ref
    assert_equal actor.public_id, event.actor_ref
    assert_predicate event.operation_ref, :present?
  end

  test "records a committed notifiable preference change inside the source transaction" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(user: actor, address: "notification-audit@example.test", confirm_policy: "1")
    email.update!(notifiable: false)

    event =
      ClientContactAuditOutbox.transaction do
        ClientContactAuditOutbox.record_preferences_changed!(actor:, email:)
      end

    assert_equal "preferences_changed", event.event_name
    assert_equal email.public_id, event.contact_ref
    assert_equal actor.public_id, event.actor_ref
  end

  test "rejects an unchanged preference value" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(user: actor, address: "unchanged-preference@example.test", confirm_policy: "1")
    email.reload

    error =
      assert_raises(ArgumentError) do
        ClientContactAuditOutbox.transaction do
          ClientContactAuditOutbox.record_preferences_changed!(actor:, email:)
        end
      end

    assert_equal "Email preference audit requires a committed preference change", error.message
  end

  test "rejects an email owned by a different actor" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(user: actor, address: "different-owner@example.test", confirm_policy: "1")
    email.update!(promotional: false)

    error =
      assert_raises(ArgumentError) do
        ClientContactAuditOutbox.transaction do
          ClientContactAuditOutbox.record_preferences_changed!(actor: other_actor, email:)
        end
      end

    assert_equal "Email preference audit owner does not match its contact", error.message
  end
end

class ClientContactAuditOutboxOutsideTransactionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "rejects a preference audit outside the source transaction" do
    error =
      assert_raises(ArgumentError) do
        ClientContactAuditOutbox.record_preferences_changed!(actor: Client.new, email: ClientEmail.new)
      end

    assert_equal "Email preference audit requires the source Zenith transaction", error.message
  end
end
