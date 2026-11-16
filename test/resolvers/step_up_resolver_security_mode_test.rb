# typed: false
# frozen_string_literal: true

require "test_helper"

# Governance retains configured authenticator eligibility; Access owns issued Step-Up proof and freshness.
class StepUpResolverSecurityModeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "configured Step-Up methods keep only the Passkey in ADVANCED and none for an invalid mode" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientPasskey.create!(
      user_id: actor.id, webauthn_id: SecureRandom.uuid, public_key: "resolver-key", uv_verified_at: Time.current,
    )
    normal_methods = StepUpConfiguredMethodsQuery.call(actor)

    assert_includes normal_methods, :passkey
    actor.update_column(:security_mode_id, SecurityModeConfigurable::ADVANCED)

    assert_equal [:passkey], StepUpConfiguredMethodsQuery.call(actor.reload)
    # The foreign key keeps an invalid mode out of the database; an unsaved one still offers nothing.
    actor.security_mode_id = 0

    assert_empty StepUpConfiguredMethodsQuery.call(actor)
  end
end
