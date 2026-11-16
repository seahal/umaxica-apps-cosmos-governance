# frozen_string_literal: true

require "test_helper"

class OperatorChronicleHaltUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "halt identity is unique by transaction and generation while other events remain independent" do
    OperatorChronicleEvent.ensure_defaults!
    OperatorChronicleLevel.ensure_defaults!
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: OperatorStatus::ACTIVE)
    attributes = {
      actor: actor,
      subject_type: "Operator",
      subject_id: actor.id,
      occurred_at: Time.current,
      event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED,
      level_id: OperatorChronicleLevel::NOTHING,
      context: { "transaction_public_id" => "transaction-a", "halt_generation" => 1 },
    }
    original = OperatorChronicle.create!(**attributes)
    duplicate = OperatorChronicle.new(**attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:context, :taken)
    roles = []
    subscriber =
      lambda do |_name, _start, _finish, _id, event|
        roles << ChronicleRecord.current_role if event[:sql].include?("operator_chronicles")
      end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      ChronicleRecord.connected_to(role: :reading) do
        assert_not duplicate.valid?
        assert duplicate.errors.of_kind?(:context, :taken)
      end
    end

    assert_includes roles, :writing
    assert_not_includes roles, :reading
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    string_generation = OperatorChronicle.new(
      **attributes.merge(context: { "transaction_public_id" => "transaction-a", "halt_generation" => "1" }),
    )

    assert_not string_generation.valid?
    assert string_generation.errors.of_kind?(:context, :taken)
    assert_predicate original, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorChronicle.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    assert_predicate OperatorChronicle.create!(
      **attributes.merge(context: { "transaction_public_id" => "transaction-a", "halt_generation" => 2 }),
    ), :persisted?
    assert_predicate OperatorChronicle.create!(
      **attributes.merge(event_id: OperatorChronicleEvent::LOGIN_SUCCESS),
    ), :persisted?
    missing_transaction = OperatorChronicle.new(
      **attributes.merge(context: { "transaction_public_id" => nil, "halt_generation" => 1 }),
    )

    assert_not missing_transaction.valid?
    assert missing_transaction.errors.of_kind?(:context, :invalid)
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorChronicle.transaction(requires_new: true) { missing_transaction.save!(validate: false) }
    end

    hostile_identity = "txn' OR 1=1 --"
    hostile_attributes = attributes.merge(
      context: { "transaction_public_id" => hostile_identity, "halt_generation" => 1 },
    )
    hostile_original = OperatorChronicle.create!(**hostile_attributes)

    assert_predicate hostile_original, :persisted?
    hostile_duplicate = OperatorChronicle.new(**hostile_attributes)

    assert_not hostile_duplicate.valid?
    assert hostile_duplicate.errors.of_kind?(:context, :taken)
    assert_predicate original.reload, :persisted?
  end
end
