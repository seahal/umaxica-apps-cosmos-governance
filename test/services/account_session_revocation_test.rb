# frozen_string_literal: true

require "test_helper"

class AccountSessionRevocationTest < ActiveSupport::TestCase
  [Client, Operator].each do |actor_class|
    [:purge!, :emergency_revoke!].each do |operation|
      test "#{actor_class.name} #{operation} exposes missing Access authority without claiming an audit success" do
        account = (actor_class == Client) ? clients(:one) : operators(:one)
        before = account.attributes
        assert_no_difference -> { AccountAccessEvent.count } do
          assert_raises(AccessOpDataUnavailableError) do
            AccountSessionRevocation.public_send(
              operation, account:, operator: operators(:two), reason_code: "security_incident",
            )
          end
        end
        assert_equal before, account.reload.attributes
      end
    end
  end
end
