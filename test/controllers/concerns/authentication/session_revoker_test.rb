# frozen_string_literal: true

require "test_helper"

class AuthenticationSessionRevokerTest < ActiveSupport::TestCase
  test "client revocation cannot query or alter retired local OP state" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    original = client.attributes

    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.tokens_for(client) }
    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.revoke_all_for(client) }
    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.tokens_for_method(client, "totp") }
    assert_equal original, client.reload.attributes
  end

  test "operator revocation cannot query or alter retired local OP state" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    original = operator.attributes

    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.tokens_for(operator) }
    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.revoke_all_for(operator) }
    assert_raises(AccessOpDataUnavailableError) { AuthenticationSessionRevoker.tokens_for_method(operator, "passkey") }
    assert_equal original, operator.reload.attributes
  end
end
