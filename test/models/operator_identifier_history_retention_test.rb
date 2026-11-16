# frozen_string_literal: true

require "test_helper"

class OperatorIdentifierHistoryRetentionTest < ActiveSupport::TestCase
  test "email and telephone history prevents deletion of its operator" do
    [OperatorEmailHistory, OperatorTelephoneHistory].each do |model|
      operator = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: OperatorStatus::ACTIVE)
      history = model.create!(
        staff: operator, fingerprint: "retained-history-#{SecureRandom.uuid}",
        attached_at: 3.days.ago, detached_at: 2.days.ago, created_at: 2.days.ago,
      )

      assert_not operator.destroy
      assert_predicate history.reload, :persisted?
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          Operator.transaction(requires_new: true) { Operator.where(id: operator.id).delete_all }
        end

      assert_kind_of PG::RestrictViolation, error.cause
    end
  end
end
