# typed: false
# frozen_string_literal: true

require "test_helper"

# Mass unit tops for still-cold raise/return arms that do not need the request stack.
class BranchCoverageBatch24MassEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "Withdrawable recovery and early-termination blank arms" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    client.define_singleton_method(:deactivated_at) { nil }
    client.define_singleton_method(:recovery_deadline) { 1.day.from_now }
    client.define_singleton_method(:recovery_available_at) { nil }
    client.define_singleton_method(:suspended?) { true }
    client.define_singleton_method(:early_termination_available_at) { nil }

    assert_predicate client, :can_recover?
    assert_nil Client.new(security_mode_id: SecurityModeConfigurable::NORMAL).recovery_available_at
    assert_nil Client.new(security_mode_id: SecurityModeConfigurable::NORMAL).early_termination_available_at
    assert_not client.early_terminatable?
  end

  test "RedirectsExternalTargetResolver refuses blank origins" do
    resolver = RedirectsExternalTargetResolver.new(:rp_app, path: "/", query: {}, source: :explicit_external)
    resolver.define_singleton_method(:origin_for) { |_| "" }

    assert_equal "invalid_origin", resolver.call.failure_reason
  end
end
