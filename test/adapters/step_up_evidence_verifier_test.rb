# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceVerifierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "authority writes require Access verification even when no proof is supplied" do
    error =
      assert_raises(AccessOpDataUnavailableError) do
        StepUpEvidenceVerifier.call(evidence: nil, actor: nil, token: nil)
      end

    assert_equal :service_unavailable, error.status_code
  end

  test "a supplied proof cannot substitute for the unavailable Access authority" do
    assert_raises(AccessOpDataUnavailableError) do
      StepUpEvidenceVerifier.call(evidence: Object.new, actor: Object.new, token: Object.new)
    end
  end
end
