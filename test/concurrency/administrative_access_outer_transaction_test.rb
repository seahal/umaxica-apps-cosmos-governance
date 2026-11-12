# frozen_string_literal: true

require "test_helper"

class AdministrativeAccessOuterTransactionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app org).product(%i(commit rollback), %i(joined savepoint)).each do |realm, outcome, nesting|
    test "#{realm} administrative lock retains denial and audit only after outer #{outcome} #{nesting}" do
      operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      if realm == "app"
        account = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        event_class = AppIdentityAuthenticationEvent
      else
        account = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        event_class = OrgIdentityAuthenticationEvent
      end
      audit_scope = AccountAccessEvent.where(account_type: account.class.name, account_id: account.id)
      failure = nil
      begin
        account.class.transaction do
          if nesting == :savepoint
            account.class.transaction(requires_new: true) do
              AdministrativeAccessLock.lock!(account:, operator:, reason_code: "security_incident")
            end
          else
            AdministrativeAccessLock.lock!(account:, operator:, reason_code: "security_incident")
          end

          assert_predicate account.reload, :admin_locked?
          assert event_class.exists?(actor_ref: account.id.to_s)
          assert_equal 0, audit_scope.count
          raise ActiveRecord::Rollback if outcome == :rollback
        end
      rescue AccessOpDataUnavailableError => e
        failure = e
      end

      if outcome == :commit
        assert_instance_of AccessOpDataUnavailableError, failure
      else
        assert_nil failure
      end

      assert_equal outcome == :commit, account.reload.admin_locked?
      assert_equal outcome == :commit, event_class.exists?(actor_ref: account.id.to_s)
      assert_equal (outcome == :commit) ? 1 : 0, audit_scope.count
    ensure
      event_class&.where(actor_ref: account.id.to_s)&.delete_all if account
      audit_scope&.delete_all
      account&.delete
      operator&.delete
    end
  end

  %w(app org).each do |realm|
    test "#{realm} administrative unlock refuses absent Access before changing denial or history" do
      operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      account =
        if realm == "app"
          Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        else
          Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        end
      account.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
        admin_locked_at: Time.current, admin_locked_by_operator_id: operator.id,
        admin_locked_reason_code: "security_incident",
      )
      original = account.attributes
      audit_scope = AccountAccessEvent.where(account_type: account.class.name, account_id: account.id)

      assert_raises(AccessOpDataUnavailableError) do
        AdministrativeAccessLock.unlock!(account:, operator:, reason_code: "operator_error_recovery")
      end
      assert_equal original, account.reload.attributes
      assert_equal 0, audit_scope.count
    ensure
      audit_scope&.delete_all
      account&.delete
      operator&.delete
    end
  end
end
