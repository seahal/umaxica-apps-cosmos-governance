# frozen_string_literal: true

require "test_helper"
require "timeout"

class WithdrawalOuterTransactionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "withdrawal start records its start time after waiting for the actor lock" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    occurrences = ClientOccurrence.where(event_type: "withdrawal.requested")
      .where("context ->> 'subject_public_id' = ?", actor.public_id)
    ready = Queue.new
    worker = nil
    observed_at = nil

    Client.transaction do
      actor.lock!
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            WithdrawalLifecycle.start!(actor: Client.find(actor.id))
          end
        end
      pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            Client.uncached do
              Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
            end
          break if blocked

          Thread.pass
        end
      end
      observed_at = Client.database_now
    end

    Timeout.timeout(10) { worker.value }
    flow = ClientWithdrawalFlow.find_by!(client_id: actor.id)

    assert_operator flow.began_at, :>=, observed_at
  ensure
    worker&.join(10)
    occurrences&.delete_all
    ClientWithdrawalFlow.where(client_id: actor.id).destroy_all if actor
    actor&.delete
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal recovery inside #{nesting} waits for outer #{outcome}" do
      past = Client.database_now - 2.days
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        withdrawal_started_at: past, deactivated_at: past, discard_at: past, purge_eligible_at: 29.days.from_now,
      )
      flow = ClientWithdrawalFlow.create!(
        client: actor, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
      )
      privacy_request = ClientPrivacyRequest.create!(
        client: actor, status_id: ClientPrivacyRequestStatus::RECEIVED, request_kind: "erasure", jurisdiction: "jp",
        request_source: "self_service", received_at: past, response_due_at: 30.days.from_now,
      )
      occurrences = ClientOccurrence.where(event_type: ["withdrawal.recovered", "privacy_erasure.cancelled"])
        .where("context ->> 'subject_public_id' = ?", actor.public_id)

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { WithdrawalLifecycle.recover!(actor:) }
        else
          WithdrawalLifecycle.recover!(actor:)
        end

        assert_equal ClientPrivacyRequestStatus::CANCELLED, privacy_request.reload.status_id
        assert_predicate flow.reload, :withdrawal_recovered?
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal outcome == :commit, flow.reload.withdrawal_recovered?
      assert_equal outcome == :commit, privacy_request.reload.status_id == ClientPrivacyRequestStatus::CANCELLED
      assert_equal (outcome == :commit) ? 2 : 0, occurrences.count
    ensure
      occurrences&.delete_all
      ClientPrivacyRequest.where(id: privacy_request.id).delete_all if privacy_request
      flow&.destroy!
      actor&.delete
    end
  end

  %i(commit rollback).product(%i(joined savepoint)).each do |outcome, nesting|
    test "withdrawal start inside #{nesting} waits for outer #{outcome}" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      occurrences = ClientOccurrence.where(event_type: "withdrawal.requested")
        .where("context ->> 'subject_public_id' = ?", actor.public_id)

      Client.transaction do
        if nesting == :savepoint
          Client.transaction(requires_new: true) { WithdrawalLifecycle.start!(actor:) }
        else
          WithdrawalLifecycle.start!(actor:)
        end

        assert_equal 1, ClientWithdrawalFlow.where(client_id: actor.id).count
        assert_empty occurrences
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal (outcome == :commit) ? 1 : 0, ClientWithdrawalFlow.where(client_id: actor.id).count
      assert_equal (outcome == :commit) ? 1 : 0, occurrences.count
    ensure
      occurrences&.delete_all
      ClientWithdrawalFlow.where(client_id: actor.id).destroy_all if actor
      actor&.delete
    end
  end

  %w(suspend terminate).product(%i(commit rollback), %i(joined savepoint)).each do |action, outcome, nesting|
    test "withdrawal #{action} retains Gov denial and reports absent Access after outer #{outcome} #{nesting}" do
      actor_id = SecureRandom.random_number(1 << 60) + 1_000_000_000
      if ClientNotificationRecord.exists?(user_id: actor_id) || AvatarAssignment.exists?(user_id: actor_id)
        raise ArgumentError, "synthetic actor ID collides with existing cross-database children"
      end

      past = Client.database_now - 10.days
      actor = Client.create!(
        id: actor_id, security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        created_at: past - 1.day,
      )
      if action == "terminate"
        actor.update!(
          withdrawal_started_at: past, deactivated_at: past, discard_at: past, withdrawn_at: past,
          purge_eligible_at: 21.days.from_now,
        )
      end
      flow = ClientWithdrawalFlow.create!(
        client: actor,
        status_id: (action == "suspend") ? ClientWithdrawalFlowStatus::REQUESTED : ClientWithdrawalFlowStatus::DISCARDED,
        began_at: past, discard_at: Float::INFINITY,
      )
      event_type = (action == "suspend") ? "withdrawal.deactivated" : "withdrawal.terminated"
      occurrences = ClientOccurrence.where(event_type:)
        .where("context ->> 'subject_public_id' = ?", actor.public_id)
      original_actor = actor.reload.attributes
      original_flow = flow.reload.attributes
      failure = nil
      begin
        Client.transaction do
          if nesting == :savepoint
            Client.transaction(requires_new: true) do
              case action
              when "suspend" then WithdrawalLifecycle.suspend!(actor:)
              when "terminate" then WithdrawalLifecycle.terminate!(actor:)
              end
            end
          else
            case action
            when "suspend" then WithdrawalLifecycle.suspend!(actor:)
            when "terminate" then WithdrawalLifecycle.terminate!(actor:)
            end
          end

          assert AppIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
          assert_empty occurrences
          raise ActiveRecord::Rollback if outcome == :rollback
        end
      rescue AccessOpDataUnavailableError => e
        failure = e
      end

      if action == "terminate"
        # Access-owned purge state is a prerequisite, so termination must roll back before its stop event.
        assert_instance_of AccessOpDataUnavailableError, failure
        assert_equal original_actor, actor.reload.attributes
        assert_equal original_flow, flow.reload.attributes
        assert_not AppIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
        assert_empty occurrences
      else
        if outcome == :commit
          assert_instance_of AccessOpDataUnavailableError, failure
        else
          assert_nil failure
        end

        assert_equal outcome == :commit, AppIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
        assert_equal outcome == :commit, actor.reload.deactivated_at.present?
        assert_equal outcome == :commit, flow.reload.withdrawal_discarded?
        assert_equal (outcome == :commit) ? 1 : 0, occurrences.count
      end
    ensure
      AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
      occurrences&.delete_all
      flow&.destroy!
      actor&.delete
    end
  end
end
