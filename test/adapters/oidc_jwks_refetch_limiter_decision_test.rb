# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcJwksRefetchLimiterDecisionTest < ActiveSupport::TestCase
  test "refetch decisions expose their state and successful cached outcome" do
    lease = OidcJwksRefetchLimiter::Decision.new(kind: :lease, outcome: nil, kids: [])
    window = OidcJwksRefetchLimiter::Decision.new(kind: :window, outcome: "ok", kids: ["kid-1"])
    busy = OidcJwksRefetchLimiter::Decision.new(kind: :busy, outcome: nil, kids: [])

    assert_predicate lease, :lease?
    assert_predicate window, :window?
    assert_predicate busy, :busy?
    assert_predicate window, :ok?
    assert_not_predicate busy, :ok?
  end
end
