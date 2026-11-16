# frozen_string_literal: true

require "test_helper"

class SignRiskOuterTransactionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app org).product(%i(commit rollback), %i(joined savepoint)).each do |realm, outcome, nesting|
    test "#{realm} risk stop preserves Gov transaction and reports absent Access after outer #{outcome} #{nesting}" do
      if realm == "app"
        actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        event_class = AppIdentityAuthenticationEvent
      else
        actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        event_class = OrgIdentityAuthenticationEvent
      end
      event_id = nil
      failure = nil
      begin
        actor.class.transaction do
          if nesting == :savepoint
            actor.class.transaction(requires_new: true) { SignRiskEnforcer.revoke!(actor) }
          else
            SignRiskEnforcer.revoke!(actor)
          end
          event_id = event_class.find_by!(actor_ref: actor.id.to_s).event_id

          assert_equal 1, actor.reload.authentication_epoch
          assert event_class.exists?(event_id:)
          raise ActiveRecord::Rollback if outcome == :rollback
        end
      rescue AccessOpDataUnavailableError => e
        failure = e
      end

      if outcome == :commit
        assert_instance_of AccessOpDataUnavailableError, failure
        assert_equal 1, actor.reload.authentication_epoch
        assert event_class.exists?(event_id:)
      else
        assert_nil failure
        assert_equal 0, actor.reload.authentication_epoch
        assert_not event_class.exists?(event_id:)
      end
    ensure
      event_class&.where(event_id:)&.delete_all if event_id
      actor&.delete
    end
  end
end
