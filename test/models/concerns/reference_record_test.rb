# typed: false
# frozen_string_literal: true

require "test_helper"

class ReferenceRecordTest < ActiveSupport::TestCase
  class DummyReference < ApplicationRecord
    # We create a simple class mimicking a reference table.
    # Usually they have just an id, but for tests we don't have a table.
    # Let's use an existing reference model for the test since ReferenceRecord requires a table.

    # We will test ClientStatus as a real reference model.
  end

  test "every direct ReferenceRecord host disables timestamps explicitly" do
    reference_record_hosts =
      Rails.root.glob("app/models/*.rb").select do |path|
        path.each_line.any? { |line| ["include ReferenceRecord", "include ::ReferenceRecord"].include?(line.strip) }
      end

    assert_predicate reference_record_hosts, :any?, "the reference model inventory must not be empty"

    hosts_with_implicit_timestamps =
      reference_record_hosts.reject do |path|
        path.each_line.any? { |line| line.match?(/\A\s*self\.record_timestamps = false\s*\z/) }
      end

    assert_empty hosts_with_implicit_timestamps, -> {
      "ReferenceRecord hosts must declare timestamp behavior directly: " \
        "#{hosts_with_implicit_timestamps.map { |path| path.relative_path_from(Rails.root) }.join(", ")}"
    }
  end

  test "record_timestamps is false" do
    assert_not ClientStatus.record_timestamps
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal ClientStatus::NOTHING, ClientStatus.nothing_id
  end
end
