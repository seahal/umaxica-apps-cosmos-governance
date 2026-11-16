# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientAppleNotificationEventTest < ActiveSupport::TestCase
  test "a received event schedules an exponential retry and remains nonterminal" do
    received_at = Time.utc(2026, 11, 13, 12)
    event = ClientAppleNotificationEvent.create!(
      jti: SecureRandom.uuid,
      event_type: "email-enabled",
      received_at:,
      occurred_at: received_at,
    )
    retry_at = received_at + 5.minutes

    assert_equal :retrying, event.retry_or_dead_letter!(code: "provider-timeout", now: retry_at)
    assert_not_predicate event.reload, :terminal?
    assert_equal "retrying", event.status
    assert_equal 1, event.processing_attempts
    assert_equal retry_at + 2.minutes, event.next_retry_at
    assert_equal "provider-timeout", event.failure_code
  end

  test "completing an event records its terminal processing state" do
    received_at = Time.utc(2026, 11, 13, 12)
    event = ClientAppleNotificationEvent.create!(
      jti: SecureRandom.uuid,
      event_type: "consent-revoked",
      received_at:,
      occurred_at: received_at,
      status: "retrying",
      processing_attempts: 2,
      next_retry_at: received_at + 10.minutes,
      failure_code: "provider-timeout",
    )
    completed_at = received_at + 15.minutes

    event.complete!(now: completed_at)

    assert_predicate event.reload, :terminal?
    assert_equal "completed", event.status
    assert_equal completed_at, event.processed_at
    assert_nil event.next_retry_at
    assert_equal "", event.failure_code
  end

  test "an event becomes a dead letter at the maximum attempt count" do
    received_at = Time.utc(2026, 11, 13, 12)
    event = ClientAppleNotificationEvent.create!(
      jti: SecureRandom.uuid,
      event_type: "account-deleted",
      received_at:,
      occurred_at: received_at,
      status: "retrying",
      processing_attempts: ClientAppleNotificationEvent::MAXIMUM_ATTEMPTS - 1,
    )
    dead_lettered_at = received_at + 1.minute

    assert_equal :dead_letter,
                 event.retry_or_dead_letter!(code: "attempts-exhausted", now: dead_lettered_at)
    assert_predicate event.reload, :terminal?
    assert_equal "dead_letter", event.status
    assert_equal ClientAppleNotificationEvent::MAXIMUM_ATTEMPTS, event.processing_attempts
    assert_equal dead_lettered_at, event.dead_lettered_at
    assert_nil event.next_retry_at
    assert_equal "attempts-exhausted", event.failure_code
  end

  test "an event becomes a dead letter when its retry window expires" do
    received_at = Time.utc(2026, 11, 12, 12)
    event = ClientAppleNotificationEvent.create!(
      jti: SecureRandom.uuid,
      event_type: "email-disabled",
      received_at:,
      occurred_at: received_at,
    )
    expired_at = received_at + ClientAppleNotificationEvent::MAXIMUM_RETRY_WINDOW

    assert_equal :dead_letter, event.retry_or_dead_letter!(code: "retry-window-expired", now: expired_at)
    assert_predicate event.reload, :terminal?
    assert_equal "dead_letter", event.status
    assert_equal 1, event.processing_attempts
    assert_equal expired_at, event.dead_lettered_at
  end
end
