# frozen_string_literal: true

require "test_helper"

class WebauthnPublicRegistryEntrypointsTest < ActiveSupport::TestCase
  test "APP and ORG surfaces retain only their Governance credential ownership" do
    app_surface = Webauthn::Surface.for(:app)
    org_surface = Webauthn::Surface.for(:org)

    assert_equal ClientPasskey, app_surface.passkey_class
    assert_equal OperatorPasskey, org_surface.passkey_class
  end

  test "OIDC verification result distinguishes absent and present step-up claims" do
    without_claims = OidcClientAssertionJwt::VerificationResult.new(
      authenticated: true,
      step_up_claims_state: :none,
      step_up_expectation: nil,
    )
    with_claims = OidcClientAssertionJwt::VerificationResult.new(
      authenticated: true,
      step_up_claims_state: :valid,
      step_up_expectation: OidcClientAssertionStepUpExpectationValue.new(
        grant: "sensitive-admission-grant",
        subject: "client-subject",
      ),
    )

    assert_not without_claims.step_up_claims_present?
    assert_predicate with_claims, :step_up_claims_present?
  end
end
