# frozen_string_literal: true

require "test_helper"

class CoreRpBridgePredicateContractTest < ActiveSupport::TestCase
  test "APP and ORG bridge predicates reflect their configured Core RP defaults" do
    assert_predicate CoreAppClientBridge, :core_default_client_id?
    assert_predicate CoreAppClientBridge, :core_default_audience?
    assert_predicate CoreAppClientBridge, :core_default_host?
    assert_predicate CoreOrgOperatorBridge, :core_default_client_id?
    assert_predicate CoreOrgOperatorBridge, :core_default_audience?
    assert_predicate CoreOrgOperatorBridge, :core_default_host?
  end
end
