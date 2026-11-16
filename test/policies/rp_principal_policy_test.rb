# frozen_string_literal: true

require "test_helper"

class RpPrincipalPolicyTest < ActiveSupport::TestCase
  test "ActionPolicy resolves each retained cell principal to the shared policy" do
    [RpBaseAppPrincipal.new, RpBaseOrgPrincipal.new, RpTechOrgPrincipal.new].each do |principal|
      assert_same RpPrincipalPolicy, ActionPolicy.lookup(principal)
    end
  end
end
