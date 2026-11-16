# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch9SessionsAndZerosTest < ActiveSupport::TestCase
  test "membership service invalid-state outcomes" do
    membership2 = Object.new
    membership2.define_singleton_method(:revoked?) { true }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::Suspend.new(membership: membership2).call
    end

    membership3 = Object.new
    membership3.define_singleton_method(:active?) { false }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::MakePrimary.new(membership: membership3).call
    end
  end
end
