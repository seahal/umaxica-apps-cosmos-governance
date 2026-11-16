# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementRecoveryCeremonyTest < ActiveSupport::TestCase
  test "recovery ceremony authenticates only its unconsumed opaque token" do
    client = clients(:one)
    ceremony = ClientEnforcementRecoveryCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)

    assert_equal ceremony, ClientEnforcementRecoveryCeremony.authenticate(
      public_id: ceremony.public_id, token: ceremony.plaintext_token,
    )

    ceremony.consume!

    assert_nil ClientEnforcementRecoveryCeremony.authenticate(
      public_id: ceremony.public_id,
      token: ceremony.plaintext_token,
    )
  end

  test "revoking a recovery ceremony records terminal state and rejects its token" do
    ceremony = ClientEnforcementRecoveryCeremony.issue!(
      subject: clients(:one), request: ActionDispatch::TestRequest.create,
    )

    assert_predicate ceremony, :active?
    assert ceremony.revoke!
    assert_equal ClientEnforcementRecoveryCeremony::REVOKED, ceremony.reload.status_id
    assert_not_nil ceremony.revoked_at
    assert_nil ceremony.consumed_at
    assert_not_predicate ceremony, :active?
    assert_nil ClientEnforcementRecoveryCeremony.authenticate(
      public_id: ceremony.public_id,
      token: ceremony.plaintext_token,
    )
  end
end
