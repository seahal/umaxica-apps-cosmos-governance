# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::EnforcementApprovalFailuresTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @other = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    2.times do
      OperatorPasskey.create!(
        staff: @operator, webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid, public_key: "test-public-key",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
  end

  test "approval claim and request refuse unavailable Access before any local claim or audit" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    before = the_case.reload.attributes
    before_events = EnforcementEvent.where(case_public_id: the_case.public_id).count
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApprovalOperation.claim!(
        enforcement_case: the_case, actor: @operator,
        token: Object.new, evidence: Object.new,
      )
    end
    assert_raises(AccessOpDataUnavailableError) do
      EnforcementCaseApprovalOperation.request!(
        enforcement_case: the_case, actor: @operator,
        token: Object.new, evidence: Object.new,
      )
    end
    assert_equal before, the_case.reload.attributes
    assert_equal before_events, EnforcementEvent.where(case_public_id: the_case.public_id).count
  end

  test "HTTP approval cannot claim an approver or publish an applied event without Access" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    before = the_case.reload.attributes
    before_client = @client.reload.attributes
    headers = as_staff_headers(@operator, host: @host)
    post base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
         params: { principal_effect: { access_blocking: true } }, headers: headers, as: :json

    assert_response :service_unavailable
    assert_equal before, the_case.reload.attributes
    assert_equal before_client, @client.reload.attributes
    assert_equal 0, EnforcementEvent.where(case_public_id: the_case.public_id).count
  end

  test "approval policy preserves applying and approving operator separation independently of Access" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    [@operator, @other].each do |operator|
      [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
       OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
        OperatorCapabilityGrant.create!(
          operator: operator, origin: "bootstrap", capability: capability,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
        )
      end
    end

    assert EnforcementCasePolicy.new(the_case, user: @operator).apply(:approve?)
    assert_not EnforcementCasePolicy.new(the_case, user: @other).apply(:approve?)
  end

  test "a stored appeal is not reviewed or falsely audited without Access reviewer evidence" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    appeal = AppEnforcementAppeal.create!(
      enforcement_case: the_case, reason_code: "incorrect_decision",
      statement: @client.public_id, submitted_at: Time.current,
    )
    before = appeal.reload.attributes
    assert_raises(AccessOpDataUnavailableError) do
      appeal.resolve!(
        reviewer_operator_public_id: @operator.public_id, resolution_code: "rejected",
        step_up_token: Object.new, step_up_actor: @operator, step_up_evidence: Object.new,
      )
    end
    assert_equal before, appeal.reload.attributes
    assert_equal 0, EnforcementEvent.where(case_public_id: the_case.public_id).count
  end
end
