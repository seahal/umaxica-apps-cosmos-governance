# frozen_string_literal: true

require "test_helper"

class SignRiskEventTest < ActiveSupport::TestCase
  test "serializes the event fields and its timestamp as ISO 8601" do
    occurred_at = Time.utc(2026, 11, 13, 12, 30, 45)
    event = SignRiskEvent.new("authentication_denied", payload: { reason: "policy" }, occurred_at:)

    assert_equal(
      { name: "authentication_denied", payload: { reason: "policy" }, occurred_at: "2026-11-13T12:30:45Z" },
      event.to_h,
    )
  end
end
