# typed: false
# frozen_string_literal: true

require "test_helper"

class SmsNotPhishingResistantInventoryTest < ActiveSupport::TestCase
  test "telephone SMS is an amr value and is not a phishing-resistant method" do
    actor = clients(:one)
    result = AuthenticationCredentialInventory.new(actor).call

    assert_not_includes result.phishing_resistant_methods, :telephone
    assert_not_includes result.phishing_resistant_methods, :sms
    assert_not_includes result.usable_step_up_capabilities, :telephone
  end
end
