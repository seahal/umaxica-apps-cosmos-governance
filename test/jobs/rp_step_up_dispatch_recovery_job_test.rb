# frozen_string_literal: true

require "test_helper"

class RpStepUpDispatchRecoveryJobTest < ActiveJob::TestCase
  test "recovery visits both retained Base RP cells" do
    visited_cells = []

    RpStepUpDispatchRecoveryOperation.stub(:call, ->(cell:) { visited_cells << cell }) do
      RpStepUpDispatchRecoveryJob.perform_now
    end

    assert_equal [RpCellBinding.fetch("rp_base_app"), RpCellBinding.fetch("rp_base_org")], visited_cells
  end
end
