# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUpResolverAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "legacy AAL demands are refused rather than translated into authorization" do
    %i(aal1 aal2 aal3).each do |level|
      error =
        assert_raises(StepUpRequirement::Invalid) do
          StepUpResolver.call(token: nil, scope: "settings_email", required_aal: level)
        end

      assert_equal "legacy AAL requirements are unsupported", error.message
    end
  end

  test "supplied legacy token proof refuses unavailable Access before reading its attributes" do
    assert_raises(AccessOpDataUnavailableError) do
      StepUpResolver.call(token: Object.new, scope: "settings_email")
    end
  end

  test "anonymous absence of proof remains unsatisfied without inventing authority" do
    result = StepUpResolver.call(
      token: nil, scope: "settings_email", session_binding: "required-session", token_binding: "required-token",
    )

    assert_not result.satisfied
    assert_not result.usable_token
    assert_nil result.required_aal
    assert_nil result.satisfied_at
    assert_nil result.expires_at
    assert_nil result.method
    assert_equal "settings_email", result.scope
    assert_not result.session_bound
    assert_not result.token_bound
  end

  test "an explicitly disabled requirement needs no proof but never becomes a usable token" do
    requirement = StepUpRequirement.new(step_up_required: false)
    result = StepUpResolver.call(token: nil, requirement:)

    assert result.satisfied
    assert_not result.usable_token
    assert_nil result.required_aal
    assert_nil result.satisfied_at
    assert_nil result.expires_at
    assert_nil result.method
    assert_nil result.scope
  end
end
