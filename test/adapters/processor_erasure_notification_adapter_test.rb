# frozen_string_literal: true

require "test_helper"

class ProcessorErasureNotificationAdapterTest < ActiveSupport::TestCase
  test "the base adapter fails explicitly when retry policy is not implemented" do
    error =
      assert_raises(NotImplementedError) do
        ProcessorErasureNotificationAdapter.new.retry_policy
      end

    assert_equal "processor adapter must expose a finite retry policy", error.message
  end

  test "the base adapter fails explicitly when dispatch is not implemented" do
    error =
      assert_raises(NotImplementedError) do
        ProcessorErasureNotificationAdapter.new.dispatch(notification: Object.new, attempt: Object.new)
      end

    assert_equal "processor adapter must implement dispatch", error.message
  end

  test "the base adapter fails explicitly when receipt verification is not implemented" do
    error =
      assert_raises(NotImplementedError) do
        ProcessorErasureNotificationAdapter.new.verify_receipt(notification: Object.new, raw_receipt: "receipt")
      end

    assert_equal "processor adapter must verify and normalize receipts", error.message
  end
end
