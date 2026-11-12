# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AdministrativeAccessLockTest < ActiveSupport::TestCase
  test "a reserved operator does not permit locking the last available operator" do
    target = operators(:one)
    operator = operators(:two)
    Operator.where.not(id: target.id).find_each { |other| other.update!(status_id: OperatorStatus::RESERVED) }

    assert_raises(AdministrativeAccessLock::LastEnabledOperatorError) do
      AdministrativeAccessLock.lock!(account: target, operator: operator, reason_code: "security_incident")
    end
    assert_predicate target.reload, :access_enabled?
  end

  test "does not lock the last enabled operator" do
    operator = operators(:one)

    Operator.where.not(id: operator.id).find_each do |other|
      other.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
        admin_locked_at: Time.current,
        admin_locked_by_operator_id: operator.id,
        admin_locked_reason_code: "security_incident",
      )
    end

    assert_raises(AdministrativeAccessLock::LastEnabledOperatorError) do
      AdministrativeAccessLock.lock!(
        account: operator,
        operator: operator,
        reason_code: "security_incident",
      )
    end
  end

  test "an unregistered reason code is refused before anything is written" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_no_difference -> { AccountAccessEvent.count } do
        assert_raises(ArgumentError) do
          AdministrativeAccessLock.lock!(account: client, operator: operator, reason_code: "not_a_reason")
        end
      end

    assert_equal "reason_code is invalid", error.message
  end
  test "committed deny retains audit and exposes missing remote delivery" do
    client = clients(:one)
    assert_raises(AccessOpDataUnavailableError) do
      AdministrativeAccessLock.lock!(account: client, operator: operators(:one), reason_code: "security_incident")
    end
    assert_predicate client.reload, :admin_locked?
    assert AccountAccessEvent.exists?(account_type: "Client", account_id: client.id, event_type: "admin_lock")
  end

  test "unlock cannot reenable account without remote authority" do
    client = clients(:one)
    client.update_columns(admin_locked_at: Time.current)
    before = client.reload.attributes
    assert_raises(AccessOpDataUnavailableError) do
      AdministrativeAccessLock.unlock!(
        account: client, operator: operators(:one),
        reason_code: "operator_error_recovery",
      )
    end
    assert_equal before, client.reload.attributes
  end
end
