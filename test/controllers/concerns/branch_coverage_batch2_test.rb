# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch2Test < ActiveSupport::TestCase
  test "Avatar current binding nil for unpersisted records" do
    avatar = Avatar.new

    assert_nil avatar.current_avatar_persona_binding
  end
end
