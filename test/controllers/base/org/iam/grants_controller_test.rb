# frozen_string_literal: true

require "test_helper"

class Base::Org::Iam::GrantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @other = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    2.times do
      OperatorPasskey.create!(
        staff: @operator, webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid, public_key: "test-public-key",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
  end

  test "delegation policy never widens the granter capabilities or delegates bootstrap IAM authority" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    candidate = OperatorCapabilityGrant.new(operator: @other, capability: OperatorCapabilityGrant::TECH_ACCESS)

    assert_not OperatorCapabilityGrantPolicy.new(candidate, user: @operator).apply(:create?)
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert OperatorCapabilityGrantPolicy.new(candidate, user: @operator).apply(:create?)
    candidate.operator = @operator

    assert_not OperatorCapabilityGrantPolicy.new(candidate, user: @operator).apply(:create?)
    candidate.operator = @other
    [*OperatorCapabilityGrant::BOOTSTRAP_ONLY_CAPABILITIES, "unknown.capability", nil, ""].each do |capability|
      candidate.capability = capability

      assert_not OperatorCapabilityGrantPolicy.new(candidate, user: @operator).apply(:create?)
    end
  end

  test "unavailable owner refuses grant creation and revocation without modifying grants or writing success audits" do
    grant = OperatorCapabilityGrant.create!(
      operator: @other, origin: "bootstrap", capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    before = grant.reload.attributes
    before_count = OperatorCapabilityGrant.count
    before_audits = Chronicle.where(action: %w(iam.capability.granted iam.capability.revoked)).count
    headers = as_staff_headers(@operator, host: @host)
    get new_base_org_iam_grant_url(ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    post base_org_iam_grants_url(host: @host),
         params: { operator_public_id: @other.public_id,
                   capability: OperatorCapabilityGrant::TECH_ACCESS,
                   reason_code: "duty_assignment",
                   duration_days: "30",
                   operation_id: SecureRandom.uuid, },
         headers: headers

    assert_response :service_unavailable
    post base_org_iam_grant_revocation_url(grant.public_id, host: @host),
         params: { reason_code: "duty_ended", operation_id: SecureRandom.uuid }, headers: headers

    assert_response :service_unavailable
    assert_equal before, grant.reload.attributes
    assert_equal before_count, OperatorCapabilityGrant.count
    assert_equal before_audits, Chronicle.where(action: %w(iam.capability.granted iam.capability.revoked)).count
  end
end
