# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyRefusalCodeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [IdentityStepUpCeremonyContract::Error].each do |error_class|
    test "#{error_class.name} raised with only a message carries the unclassified code" do
      error = assert_raises(error_class) { raise error_class, "refused" }

      assert_equal "unclassified", error.code
      assert_equal "refused", error.message
    end

    test "#{error_class.name} carries a code from the refusal taxonomy" do
      error = error_class.new("refused", code: "transaction_conflict")

      assert_equal "transaction_conflict", error.code
    end

    # Sentinels: missing, empty, a Symbol spelling of a valid code, and an unknown word.
    [nil, "", :transaction_conflict, "not_a_code"].each do |code|
      test "#{error_class.name} rejects the code #{code.inspect} instead of logging it" do
        assert_raises(ArgumentError) { error_class.new("refused", code: code) }
      end
    end
  end
end
