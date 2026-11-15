# frozen_string_literal: true

require "test_helper"

class AvatarBureauAgentGrantTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::AvatarBureauAgentGrant)
  end

  test "effective_at? includes the grant start and excludes the revocation instant" do
    granted_at = Time.utc(2026, 11, 13, 12)
    revoked_at = granted_at + 1.hour
    grant = AvatarBureauAgentGrant.new(granted_at:, revoked_at:)

    assert_not grant.effective_at?(granted_at - 1.second)
    assert grant.effective_at?(granted_at)
    assert grant.effective_at?(revoked_at - 1.second)
    assert_not grant.effective_at?(revoked_at)
    assert_not grant.effective_at?(revoked_at + 1.second)
  end
end
