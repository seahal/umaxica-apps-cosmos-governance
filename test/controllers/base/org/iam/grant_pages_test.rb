# frozen_string_literal: true

require "test_helper"

class Base::Org::Iam::GrantPagesTest < ActionDispatch::IntegrationTest
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

  test "grant read permission still requires a live Governance capability" do
    assert_not OperatorCapabilityGrantPolicy.new(OperatorCapabilityGrant, user: @operator).apply(:index?)
    grant = OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert OperatorCapabilityGrantPolicy.new(OperatorCapabilityGrant, user: @operator).apply(:index?)
    grant.update!(expires_at: 1.second.ago)

    assert_not OperatorCapabilityGrantPolicy.new(OperatorCapabilityGrant, user: @operator.reload).apply(:index?)
  end

  test "grant list detail and unknown detail disclose nothing without Access caller resolution" do
    grant = OperatorCapabilityGrant.create!(
      operator: @other, origin: "bootstrap", capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    before = grant.reload.attributes
    headers = as_staff_headers(@operator, host: @host)
    [base_org_iam_grants_url(q: @other.public_id, ri: "jp", host: @host),
     base_org_iam_grant_url(grant.public_id, ri: "jp", host: @host),
     base_org_iam_grant_url("unknown-grant", ri: "jp", host: @host),].each do |url|
      get url, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, grant.public_id
      assert_equal before, grant.reload.attributes
    end
  end

  test "revocation policy requires its separate capability and refuses an already revoked grant" do
    grant = OperatorCapabilityGrant.create!(
      operator: @other, origin: "bootstrap", capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end

    assert OperatorCapabilityGrantPolicy.new(grant, user: @operator).apply(:revoke?)
    grant.revoke!(by: @operator, reason_code: "duty_ended")

    assert_not OperatorCapabilityGrantPolicy.new(grant.reload, user: @operator).apply(:revoke?)
  end
end
