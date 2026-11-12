# typed: false
# frozen_string_literal: true

require "test_helper"

class TargetedModelLineCoverageTest < ActiveSupport::TestCase
  test "withdrawal occurrence helpers reject unsupported types and digest optional values" do
    unsupported = Object.new

    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_class_for(unsupported) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_status_id_for(String) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_status_class_for(String) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.surface_for(unsupported) }
    assert_nil WithdrawalOccurrenceRecording.digest_optional(nil)
    assert_equal Digest::SHA256.hexdigest("agent"), WithdrawalOccurrenceRecording.digest_optional("agent")
  end

  test "processor notification status helpers and pending scope are executable" do
    assert_equal "PENDING", ClientProcessorErasureNotification.status_name_for(
      ClientProcessorErasureNotification.status_id_for("PENDING"),
    )
    notification = ClientProcessorErasureNotification.new(
      status_id: ClientProcessorErasureNotification.status_id_for("PENDING"),
    )

    assert_predicate notification, :pending?
    assert_kind_of ActiveRecord::Relation, ClientProcessorErasureNotification.pending_for_processing
  end

  test "retention and privacy state helpers expose status names and predicates" do
    active_id = ClientRetentionHold.status_id_for("ACTIVE")

    assert_equal "ACTIVE", ClientRetentionHold.status_name_for(active_id)
    assert_predicate ClientRetentionHold.new(status_id: active_id, expires_at: nil), :active_at?

    received_id = ClientPrivacyRequest.status_id_for("RECEIVED")

    assert_equal "RECEIVED", ClientPrivacyRequest.status_name_for(received_id)
    blocking_id = ClientPrivacyRequest.status_id_for("VERIFIED")

    assert_predicate ClientPrivacyRequest.new(status_id: blocking_id), :recovery_blocking?
  end

  test "retention hold is inactive when released or expired" do
    released = ClientRetentionHold.new(
      status_id: ClientRetentionHold.status_id_for("RELEASED"),
      expires_at: nil,
    )
    expired = ClientRetentionHold.new(
      status_id: ClientRetentionHold.status_id_for("ACTIVE"),
      expires_at: 1.minute.ago,
    )

    assert_not_predicate released, :active_at?
    assert_not_predicate expired, :active_at?
  end

  test "simple public model mappings return their public ids and fallback owners" do
    assert_equal "passkey-id", ClientPasskey.new(public_id: "passkey-id").to_param
    assert_equal "request-id", OperatorLifecycleRequest.new(public_id: "request-id").to_param
  end
end
