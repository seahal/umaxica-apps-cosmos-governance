# typed: false
# frozen_string_literal: true

require "test_helper"

# D-134: the database makes the ORG halt audit exactly-once per transaction and halt generation.
class OperatorChronicleSignFlowHaltedTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
  end

  test "a second SIGN_FLOW_HALTED row for the same transaction and generation is rejected" do
    halt!(transaction: "txn-a", generation: "100")

    duplicate = OperatorChronicle.new(
      base_attributes.merge(context: { transaction_public_id: "txn-a", halt_generation: "100" }),
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:context, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorChronicle.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "another generation or another transaction is a separate halt" do
    halt!(transaction: "txn-b", generation: "100")

    assert_nothing_raised do
      halt!(transaction: "txn-b", generation: "101")
      halt!(transaction: "txn-c", generation: "100")
    end
  end

  test "a SIGN_FLOW_HALTED row without its correlation keys is rejected" do
    [
      {},
      { transaction_public_id: "txn-a" },
      { halt_generation: "100" },
      { nested: { transaction_public_id: "txn-a", halt_generation: "100" } },
      ["transaction_public_id"],
    ].each do |context|
      record = OperatorChronicle.new(base_attributes.merge(context: context))

      assert_not record.valid?
      assert record.errors.of_kind?(:context, :invalid)
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorChronicle.transaction(requires_new: true) { record.save!(validate: false) }
      end
    end
  end

  test "halt identities that extract to SQL NULL are rejected by the model and database" do
    [
      { transaction_public_id: nil, halt_generation: "100" },
      { transaction_public_id: "txn-a", halt_generation: nil },
      ["transaction_public_id", "halt_generation"],
    ].each do |context|
      record = OperatorChronicle.new(base_attributes.merge(context: context))

      assert_not record.valid?
      assert record.errors.of_kind?(:context, :invalid)
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorChronicle.transaction(requires_new: true) { record.save!(validate: false) }
      end
    end
  end

  test "other events are unaffected by the halt index and check" do
    assert_nothing_raised do
      2.times do
        OperatorChronicle.create!(base_attributes.merge(event_id: OperatorChronicleEvent::LOGGED_IN, context: {}))
      end
    end
  end

  private

  def halt!(transaction:, generation:)
    OperatorChronicle.create!(
      base_attributes.merge(context: { transaction_public_id: transaction, halt_generation: generation }),
    )
  end

  def base_attributes
    { actor: @operator,
      subject_type: "OrgNormalSignInTransaction",
      subject_id: @operator.id,
      event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED,
      occurred_at: Time.current, }
  end
end
