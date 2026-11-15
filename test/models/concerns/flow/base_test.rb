# typed: false
# frozen_string_literal: true

require "test_helper"

class FlowBaseTest < ActiveSupport::TestCase
  class CycleBaseTestRecord < ApplicationRecord
    self.table_name = "cycle_base_test_records"

    include Retainable
    include FlowBase

    attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
    attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }
    validates :discard_at, presence: true
    validates :purge_eligible_at, presence: true
    validate :retention_order_valid
    validate :retention_times_not_before_created_at, on: :update
    Retainable.register_host(self)

    def self.cycle_status_column_name = :cycle_status_id

    cycle_status_column :cycle_status_id
  end

  class UnconfiguredCycleBaseTestRecord < ApplicationRecord
    self.table_name = "cycle_base_test_records"

    include FlowBase
  end

  class MisconfiguredCycleBaseTestRecord < ApplicationRecord
    self.table_name = "cycle_base_test_records"

    include FlowBase

    def self.cycle_status_column_name = :nonexistent_status_column

    cycle_status_column :nonexistent_status_column
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:cycle_base_test_records, force: true) do |t|
      t.integer(:cycle_status_id, null: false)
      t.datetime(:discard_at, null: false)
      t.datetime(:purge_eligible_at, null: false)
      t.datetime(:expires_at)
      t.timestamps
    end
    CycleBaseTestRecord.reset_column_information
    UnconfiguredCycleBaseTestRecord.reset_column_information
    MisconfiguredCycleBaseTestRecord.reset_column_information
  end

  teardown do
    @connection.drop_table(:cycle_base_test_records, if_exists: true)
  end

  test "cycle_status_id reads the configured status foreign key" do
    record = build_record(cycle_status_id: 10)

    assert_equal 10, record.cycle_status_id
    assert record.cycle_status?(10)
    assert_not record.cycle_status?(20)
  end

  test "cycle_status_id requires an explicit status column configuration" do
    record = UnconfiguredCycleBaseTestRecord.create!(
      cycle_status_id: 10,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )

    error = assert_raises(FlowConfigurationError) { record.cycle_status_id }

    assert_match(/cycle_status_column/, error.message)
  end

  test "FlowBase does not expose a generic cycle status writer" do
    record = build_record

    assert_not_respond_to record, :transition_cycle_to!
  end

  test "ensure_cycle_column raises for missing column" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = MisconfiguredCycleBaseTestRecord.create!(
      cycle_status_id: 10,
      discard_at: now + 1.day,
      purge_eligible_at: now + 2.days,
    )

    error = assert_raises(FlowConfigurationError) { record.cycle_status_id }

    assert_match(/does not have nonexistent_status_column/, error.message)
  end

  test "retainable_required raises when Retainable is not included" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = UnconfiguredCycleBaseTestRecord.create!(
      cycle_status_id: 10,
      discard_at: now + 1.day,
      purge_eligible_at: now + 2.days,
    )

    error = assert_raises(FlowConfigurationError) { record.cycle_accessible? }

    assert_match(/include Retainable/, error.message)
  end

  test "with_cycle_lock requires a block" do
    record = build_record

    error = assert_raises(ArgumentError) { record.send(:with_cycle_lock) }

    assert_match(/block required/, error.message)
  end

  test "with_cycle_lock rejects unpersisted records" do
    record = CycleBaseTestRecord.new(
      cycle_status_id: 10,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )

    error = assert_raises(FlowInvalidTransition) { record.send(:with_cycle_lock) { nil } }

    assert_match(/cycle must be persisted/, error.message)
  end

  private

  def build_record(**attrs)
    defaults = {
      cycle_status_id: 10,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    }
    CycleBaseTestRecord.create!(defaults.merge(attrs))
  end
end
