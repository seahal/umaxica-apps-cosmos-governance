# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRiskEnforcerTest < ActiveSupport::TestCase
  test "a real step-up risk score fails closed while Access step-up is unavailable" do
    actor = clients(:one)
    5.times do |index|
      ClientOccurrence.create!(
        body: "risk-auth-failed-#{index}",
        context: { user_id: actor.id },
        event_type: "risk.auth_failed",
      )
    end

    assert_equal 60, SignRiskEngine.score(user_id: actor.id)

    SignRiskEnforcer.stub(:feature_enabled?, true) do
      assert_raises(AccessOpDataUnavailableError) { SignRiskEnforcer.call(actor) }
    end
  end
end
