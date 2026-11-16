# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceCollectionJobTest < ActiveJob::TestCase
  test "batch rejects zero and five hundred one and accepts adjacent valid boundaries" do
    [0, 501, nil, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(batch_size: value) }
    end
    [1, 2, 499, 500].each do |value|
      assert_no_enqueued_jobs do
        ClientSecretIssuanceCollectionJob.perform_now(batch_size: value, after_id: 0, through_id: 0)
      end
    end
  end

  test "cursor rejects negative noninteger and reversed bounds and accepts equality and its upper neighbor" do
    [-1, nil, "0", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(after_id: value) }
    end
    [-1, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(through_id: value) }
    end
    assert_raises(ArgumentError) { ClientSecretIssuanceCollectionJob.perform_now(after_id: 1, through_id: 0) }
    [0, 1].each do |value|
      assert_no_enqueued_jobs do
        ClientSecretIssuanceCollectionJob.perform_now(after_id: 0, through_id: value)
      end
    end
  end
end
