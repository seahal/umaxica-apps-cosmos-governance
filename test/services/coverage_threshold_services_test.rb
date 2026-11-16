# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdServicesTest < ActiveSupport::TestCase
  test "credential inventory result exposes availability and removal predicates" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, sign_in_methods: [:email],
      step_up_methods: [:passkey],
      uv_step_up_methods: [:passkey], contact_identifiers: [:email],
      phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.sign_in_methods
    assert_predicate result, :has_usable_sign_in_capability?
    assert_predicate result, :has_usable_step_up_capability?
    assert_equal [:email], result.usable_sign_in_capabilities
    assert_equal [:passkey], result.usable_step_up_capabilities
    assert_equal 1, result.usable_sign_in_capabilities.length
  end
end
