# typed: false
# frozen_string_literal: true

require "test_helper"

# A sweep over the places that refuse an input they were never taught. Each is a
# single line, and each is the difference between a value being rejected at the
# boundary and being carried further as though it meant something. They are
# gathered here because the failure mode is identical everywhere: a new surface,
# provider or state added without teaching the mapping must fail loudly.
class UnsupportedInputRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The challenge verifier is injected through configuration so no production
  # class carries a test-only branch. An unset one has to fail loudly rather than
  # leave every challenge unverified.
  test "an unconfigured challenge verifier is refused rather than skipped" do
    configured = Rails.application.config.x.turnstile.verifier
    Rails.application.config.x.turnstile.verifier = nil

    error = assert_raises(RuntimeError) { Turnstile::VerifierFactory.current }

    assert_match(/turnstile\.verifier is not configured/, error.message)
  ensure
    Rails.application.config.x.turnstile.verifier = configured
  end

  test "quota policies refuse a principal from another surface" do
    account_policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED))
    organization_policy = Acme::OrganizationQuotaPolicy.new(surface: :org, principal: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL))

    assert_raises(ArgumentError) { account_policy.current_count }
    assert_raises(ArgumentError) { organization_policy.current_count }
  end
end
