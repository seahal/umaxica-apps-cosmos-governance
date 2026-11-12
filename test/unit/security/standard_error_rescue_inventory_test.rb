# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StandardErrorRescueInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REVIEWED_RESCUES = {
    "app/controllers/concerns/actor_support.rb" => {
      count: 4,
      classification: "auth boundary; each rescue logs and re-raises ActorSupport::ResolutionError",
    },
    "app/controllers/concerns/authentication_audit_writer.rb" => {
      count: 4,
      classification: "best-effort audit side effect with outbox/fallback recovery",
    },
    "app/controllers/concerns/authorization_audit.rb" => {
      count: 1,
      classification: "best-effort authorization failure audit side effect",
    },
    "app/controllers/concerns/preference_base.rb" => {
      count: 1,
      classification: "Preference current-resource resolution; failures are re-raised as resolution errors",
    },
  }.freeze

  test "reviewed StandardError rescues stay classified" do
    offenders =
      REVIEWED_RESCUES.filter_map do |path, expected|
        actual = rescue_count(path)
        next if actual == expected.fetch(:count) && expected.fetch(:classification).present?

        "#{path}: expected #{expected.fetch(:count)}, got #{actual} (#{expected.fetch(:classification)})"
      end

    assert_empty offenders, "Reviewed StandardError rescue inventory changed:\n#{offenders.join("\n")}"
  end

  private

  def rescue_count(path)
    Rails.root.join(path).read.scan(/\brescue\s+StandardError\b/).size
  end
end
