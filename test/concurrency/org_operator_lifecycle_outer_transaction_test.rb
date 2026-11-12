# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleOuterTransactionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(withdraw suspend terminate).product(%i(commit rollback), %i(joined savepoint)).each do |action, outcome, nesting|
    test "operator #{action} retains Gov denial and reports absent Access after outer #{outcome} #{nesting}" do
      requester = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      executor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      target = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      request = OperatorLifecycleRequest.create!(
        action:, status: OperatorLifecycleRequest::STATUS_APPROVED, target_operator: target,
        requested_by_operator: requester, approved_by_operator: executor, approved_at: Time.current, reason: "approved",
      )
      failure = nil
      begin
        OrgPrincipalRecord.transaction do
          if nesting == :savepoint
            OrgPrincipalRecord.transaction(requires_new: true) do
              assert_predicate OrgOperatorLifecycleExecute.call(request:, actor: executor), :success?
            end
          else
            assert_predicate OrgOperatorLifecycleExecute.call(request:, actor: executor), :success?
          end

          assert_predicate request.reload, :executed?
          assert_predicate target.reload.deactivated_at, :present?
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

      assert_equal outcome == :commit, request.reload.executed?
      assert_equal outcome == :commit, target.reload.deactivated_at.present?
      assert_equal outcome == :commit, OrgIdentityAuthenticationEvent.exists?(actor_ref: target.id.to_s)
    ensure
      OrgIdentityAuthenticationEvent.where(actor_ref: target.id.to_s).delete_all if target
      request&.delete
      target&.delete
      requester&.delete
      executor&.delete
    end
  end
end
