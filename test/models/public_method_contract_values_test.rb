# frozen_string_literal: true

require "test_helper"

class PublicMethodContractValuesTest < ActiveSupport::TestCase
  test "a blank public identifier error names its record without substituting an internal id" do
    error = BlankPublicIdentifierError.new(record_class: Client)

    assert_equal "Client", error.record_class
    assert_equal "Client has a blank public_id and cannot be exposed to a client", error.message
  end

  test "resource lifecycle predicates distinguish active and inactive state in every family" do
    active = AuthorityResourceLifecycleStateValue::ACTIVE
    inactive = AuthorityResourceLifecycleStateValue::INACTIVE
    lifecycles = [AgentLifecycle, BureauLifecycle, EnterpriseLifecycle]

    lifecycles.each do |lifecycle_class|
      assert_predicate lifecycle_class.new(state: active), :active?
      assert_not_predicate lifecycle_class.new(state: inactive), :active?
    end
  end

  test "persisted owner cutover markers are readonly in each owner family" do
    [AgentAuthorityCutover, BureauAuthorityCutover, EnterpriseAuthorityCutover].each do |cutover_class|
      cutover = cutover_class.establish!

      assert_predicate cutover, :readonly?, cutover_class.name
    end
  end

  test "identifier inventory result serializes its stable public shape" do
    connections = [{ name: "primary", tables: [] }]
    result = IdentifierContractInventoryQuery::Result.new(
      version: IdentifierContractInventoryQuery::VERSION,
      generated_at: "2026-11-06T00:00:00Z",
      connections: connections,
    )

    assert_equal(
      { version: IdentifierContractInventoryQuery::VERSION, generated_at: "2026-11-06T00:00:00Z", connections: },
      result.to_h,
    )
    assert_equal result.to_h, JSON.parse(result.to_json, symbolize_names: true)
  end

  test "inventory results serialize summary and details without changing their shape" do
    summary = { selection_complete: true, avatars_requested: 0 }
    details = []
    avatar_result = AvatarOwnershipTransitionInventoryQuery::Result.new(summary:, details:)
    group_result = AvatarGroupOwnershipTransitionInventoryQuery::Result.new(summary:, details:)
    backfill_result = AvatarConcreteOwnershipBackfillOperation::Result.new(summary:, details:)
    group_backfill_result = AvatarGroupConcreteOwnershipBackfillOperation::Result.new(summary:, details:)
    cutover_result = AvatarOwnershipCutoverOperation::Result.new(
      status: "established",
      summary:,
      inventory: avatar_result,
      group_inventory: group_result,
    )

    assert_predicate avatar_result, :selection_complete?
    assert_equal({ summary:, details: }, group_result.to_h)
    assert_equal({ summary:, details: }, backfill_result.to_h)
    assert_equal({ summary:, details: }, group_backfill_result.to_h)
    assert_equal(
      { status: "established", summary:, inventory: avatar_result.to_h, group_inventory: group_result.to_h },
      cutover_result.to_h,
    )
    assert_equal cutover_result.to_h, JSON.parse(cutover_result.to_json, symbolize_names: true)
    assert_equal({ summary:, details: }, JSON.parse(avatar_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(group_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(backfill_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(group_backfill_result.to_json, symbolize_names: true))
  end
end
