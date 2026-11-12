# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementExpiryJobTest < ActiveJob::TestCase
  test "ends an active cooldown case whose expires_at has passed and unlocks nothing since it never blocked access" do
    client = create_test_client!
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: 2.days.ago,
      expires_at: 1.hour.ago,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    EnforcementExpiryJob.perform_now

    the_case.reload

    assert_predicate the_case.ended_at, :present?
    assert_equal "expired", the_case.end_reason
  end

  test "expiring a temporary_freeze retains admin_locked and reports missing Access release authority" do
    client = create_test_client!
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: 2.days.ago,
      expires_at: 1.hour.ago,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: 2.days.ago,
    )
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApplyOperation.call(
        enforcement_case: the_case,
        actor_operator_public_id: the_case.applied_by_operator_public_id,
      )
    end

    failures = []
    Rails.logger.stub(:error, ->(message) { failures << message }) do
      EnforcementExpiryJob.perform_now
    end
    client.reload

    assert_predicate client, :admin_locked?
    assert_predicate the_case.reload.ended_at, :present?
    assert failures.any? { |message| message.include?("AccessOpDataUnavailableError") }
    assert_not the_case.audit_event_recorded?("expired")
  end

  test "does not touch a case whose expires_at has not yet passed" do
    client = create_test_client!
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    EnforcementExpiryJob.perform_now

    assert_not_predicate the_case.reload.ended_at, :present?
  end

  private

  def create_test_client!
    Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::BOTH,
    )
  end
end
