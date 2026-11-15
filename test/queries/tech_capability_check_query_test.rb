# frozen_string_literal: true

require "test_helper"

class TechCapabilityCheckQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(operators)

  setup do
    @operator = operators(:one)
    @granter = operators(:two)
    @cell = RpCellBinding.fetch("rp_tech_org")
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    @issuer = Oidc::AcmeServiceOrigin.from_configured_host(
      hosts.visa_staff.host, default_scheme: "https",
    ).origin
    subject = OidcSubject.for(@operator, resource_type: "operator")
    principal = RpTechOrgPrincipal.create!
    identity = RpTechOrgIdentityBinding.create!(
      issuer: @issuer, realm: @cell.realm, client_id: @cell.client_id, subject:, principal:,
    )
    binding = RpTechOrgOpSessionBinding.create!(
      issuer: @issuer, realm: @cell.realm, client_id: @cell.client_id, sid: "tech-capability-test-sid",
      identity_binding: identity,
    )
    @session = RpTechOrgSession.create!(
      op_session_binding: binding, absolute_expires_at: 1.hour.from_now, installed_generation: 0,
    )
  end

  test "an active Tech RP session reads the current Operator capability on each request" do
    allowed = TechCapabilityCheckQuery.call(
      token: BaseApiAuthorityTokenIssuer.issue(rp_session: @session, audience_resource_type: "operator"),
    )

    assert_predicate allowed, :authenticated?
    assert_not allowed.allowed

    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    granted = TechCapabilityCheckQuery.call(
      token: BaseApiAuthorityTokenIssuer.issue(rp_session: @session, audience_resource_type: "operator"),
    )

    assert_predicate granted, :authenticated?
    assert_predicate granted, :allowed
  end

  test "an invalid or revoked Tech RP bearer is an authentication refusal" do
    invalid = TechCapabilityCheckQuery.call(token: "not-a-governance-token")

    assert_not_predicate invalid, :authenticated?
    assert_not invalid.allowed

    token = BaseApiAuthorityTokenIssuer.issue(rp_session: @session, audience_resource_type: "operator")
    @session.op_session_binding.update!(revoked_at: Time.current)
    revoked = TechCapabilityCheckQuery.call(token:)

    assert_not_predicate revoked, :authenticated?
    assert_not revoked.allowed
  end
end
