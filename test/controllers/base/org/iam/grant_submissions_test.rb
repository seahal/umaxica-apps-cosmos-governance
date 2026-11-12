# frozen_string_literal: true

require "test_helper"

class Base::Org::Iam::GrantSubmissionsTest < ActionDispatch::IntegrationTest
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

  test "Governance grant records retain the ticket format and 64 character boundary" do
    [[nil, true], ["", false], ["A" * 63, true], ["A" * 64, true], ["A" * 65, false],
     ["!ticket", false],].each do |ticket, valid|
      grant = OperatorCapabilityGrant.new(
        operator: @other, granted_by_operator: @operator, origin: "grant",
        capability: OperatorCapabilityGrant::TECH_ACCESS, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now, ticket_id: ticket,
      )

      assert_equal valid, grant.valid?, grant.errors.full_messages.inspect
      assert_predicate grant.errors[:ticket_id], :any? unless valid
    end
  end

  test "submission inputs never grant or falsely audit success while Access caller authority is unavailable" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
     OperatorCapabilityGrant::TECH_ACCESS,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    headers = as_staff_headers(@operator, host: @host)
    before_count = OperatorCapabilityGrant.count
    before_audits = Chronicle.where(action: "iam.capability.granted").count
    [nil, "", 0, "not-a-uuid", SecureRandom.uuid].each do |operation_id|
      post base_org_iam_grants_url(host: @host),
           params: { operator_public_id: @other.public_id,
                     capability: OperatorCapabilityGrant::TECH_ACCESS,
                     reason_code: "duty_assignment",
                     duration_days: "30",
                     operation_id: operation_id, },
           headers: headers

      assert_response :service_unavailable
      assert_equal before_count, OperatorCapabilityGrant.count
      assert_equal before_audits, Chronicle.where(action: "iam.capability.granted").count
    end
  end
end
