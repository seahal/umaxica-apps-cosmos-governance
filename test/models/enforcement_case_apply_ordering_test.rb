# frozen_string_literal: true

require "test_helper"

# Governance keeps defensive Case decisions even when Access delivery is unavailable.
# Release reconciliation never claims an unlock or rewrites a later local deny decision.
class EnforcementCaseApplyOrderingTest < ActiveSupport::TestCase
  test "reconciling an ended Case cannot clear a later administrative lock without Access" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
    end
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    end
    assert_raises(AccessOpDataUnavailableError) do
      AdministrativeAccessLock.lock!(account: client, operator: operator, reason_code: "security_incident")
    end
    before = client.reload.attributes
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile
    end
    assert_equal before, client.reload.attributes
    assert_predicate client, :admin_locked?
  end

  test "end reconciliation cannot publish a release audit before Access can authorize the unlock" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
    end
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    end
    assert_predicate client.reload, :admin_locked?
    assert_predicate the_case.reload.ended_at, :present?
    release_events = AccountAccessEvent.where(
      account_type: "Client", account_id: client.id,
      event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
    )
    assert_no_difference -> { release_events.count } do
      assert_raises(AccessOpDataUnavailableError) do
        EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile
      end
    end
    assert_predicate client.reload, :admin_locked?
  end

  test "reconciling a pending release does not advance the account cutoff or fabricate repeated unlock events" do
    client = clients(:one)
    operator = operators(:one)
    the_case = blocking_case_for(client, operator_public_id: operator.public_id)
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
    end
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
    end
    cutoff = client.reload.token_valid_after_at
    release_events = AccountAccessEvent.where(
      account_type: "Client", account_id: client.id,
      event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
    )

    travel 1.second do
      assert_no_difference -> { release_events.count } do
        assert_raises(AccessOpDataUnavailableError) do
          EnforcementCaseEndOperation.new(enforcement_case: the_case, reason: "revoked").reconcile
        end
      end
    end
    assert_equal cutoff, client.reload.token_valid_after_at
  end

  test "a real missing-operator side effect failure preserves the already decided Case" do
    client = clients(:one)
    the_case = blocking_case_for(client, operator_public_id: "operator-that-does-not-exist")
    assert_raises(ActiveRecord::RecordNotFound) do
      EnforcementCaseApplyOperation.call(
        enforcement_case: the_case,
        actor_operator_public_id: the_case.applied_by_operator_public_id,
      )
    end
    assert_equal "active", the_case.reload.state
    assert_nil the_case.sessions_revoked_at
    assert_not_predicate client.reload, :admin_locked?
  end

  test "ending blocking Cases cannot release the local deny or report Access convergence" do
    client = clients(:one)
    operator = operators(:one)
    first = blocking_case_for(client, operator_public_id: operator.public_id)
    second = blocking_case_for(client, operator_public_id: operator.public_id)

    [first, second].each do |the_case|
      assert_raises(AccessOpDataUnavailableError) do
        EnforcementCaseApplyOperation.call(enforcement_case: the_case, actor_operator_public_id: operator.public_id)
      end
    end
    assert_predicate client.reload, :admin_locked?
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.call(enforcement_case: first, reason: "revoked")
    end
    assert_predicate client.reload, :admin_locked?
    assert_nil second.reload.ended_at
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseEndOperation.call(enforcement_case: second, reason: "revoked")
    end
    assert_predicate client.reload, :admin_locked?
    assert_predicate first.reload.ended_at, :present?
    assert_predicate second.reload.ended_at, :present?
  end

  private

  def blocking_case_for(client, operator_public_id:)
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator_public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    the_case
  end
end
