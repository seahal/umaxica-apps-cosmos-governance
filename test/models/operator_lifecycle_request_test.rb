# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorLifecycleRequestTest < ActiveSupport::TestCase
  test "closed? returns true for rejected, executed or cancelled status" do
    req = OperatorLifecycleRequest.new(status: "rejected")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "executed")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "cancelled")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "pending")

    assert_not req.closed?
  end

  test "withdraw? identifies withdrawal requests only" do
    assert_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_WITHDRAW), :withdraw?
    assert_not_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_SUSPEND), :withdraw?
  end

  test "suspend? identifies suspension requests only" do
    assert_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_SUSPEND), :suspend?
    assert_not_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_WITHDRAW), :suspend?
  end

  test "terminate? identifies termination requests only" do
    assert_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_TERMINATE), :terminate?
    assert_not_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_WITHDRAW), :terminate?
  end

  test "restore? identifies restoration requests only" do
    assert_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_RESTORE), :restore?
    assert_not_predicate OperatorLifecycleRequest.new(action: OperatorLifecycleRequest::ACTION_WITHDRAW), :restore?
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorLifecycleRequest)
  end
end
