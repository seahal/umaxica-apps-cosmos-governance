# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::EnforcementCasesControllerTest < ActionDispatch::IntegrationTest
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

  test "Governance enforcement policies require read plus mutation capability and never reach the ORG realm" do
    the_case = AppEnforcementCase.new(applied_by_operator_public_id: @other.public_id)

    assert_not EnforcementCasePolicy.new(the_case, user: @operator).apply(:index?)
    assert_not EnforcementCasePolicy.new(the_case, user: @operator).apply(:create?)
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert_not EnforcementCasePolicy.new(the_case, user: @operator).apply(:create?)
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert EnforcementCasePolicy.new(the_case, user: @operator).apply(:index?)
    assert EnforcementCasePolicy.new(the_case, user: @operator).apply(:create?)
    assert_not EnforcementCasePolicy.new(OrgEnforcementCase.new, user: @operator).apply(:index?)
    assert_not EnforcementCasePolicy.new(OrgEnforcementCase.new, user: @operator).apply(:create?)
  end

  test "Governance serves local enforcement reads and refuses Access-dependent screens and mutations" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    before = the_case.reload.attributes
    before_count = AppEnforcementCase.count
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,
     OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability:, reason_code: "bootstrap",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    headers = as_staff_headers(@operator, host: @host, select_available_org_persona: true)
    [
      base_org_support_app_enforcement_cases_url(ri: "jp", host: @host),
      base_org_support_app_enforcement_case_url(the_case.public_id, ri: "jp", host: @host),
    ].each do |url|
      get url, headers: headers

      assert_response :success
      assert_equal "private, no-store", response.headers["Cache-Control"]
      assert_includes response.body, the_case.public_id
    end
    [
      new_base_org_support_app_enforcement_case_url(ri: "jp", host: @host),
      new_base_org_support_app_enforcement_case_approval_url(the_case.public_id, ri: "jp", host: @host),
      new_base_org_support_app_enforcement_case_release_url(the_case.public_id, ri: "jp", host: @host),
      new_base_org_support_app_enforcement_case_appeal_review_url(the_case.public_id, ri: "jp", host: @host),
    ].each do |url|
      get url, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_not_includes response.body, @client.public_id
      assert_not_includes response.body, '"component"'
    end
    post base_org_support_app_enforcement_cases_url(host: @host),
         params: { principal_public_id: @client.public_id,
                   kind: "cooldown",
                   duration_mode: "timed",
                   visibility: "visible",
                   release_mode: "automatic",
                   reason_code: "abuse",
                   duration_days: "1", },
         headers: headers, as: :json

    assert_response :service_unavailable
    assert_equal before, the_case.reload.attributes
    assert_equal before_count, AppEnforcementCase.count
    assert_equal 0, EnforcementEvent.where(case_public_id: the_case.public_id).count

    [base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
     base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
     base_org_support_app_enforcement_case_appeal_review_url(the_case.public_id, host: @host),].each do |url|
      post url, params: { reason_code: "reviewed" }, headers: headers, as: :json

      assert_response :service_unavailable
      assert_equal before, the_case.reload.attributes
      assert_equal 0, EnforcementEvent.where(case_public_id: the_case.public_id).count
    end
  end

  test "release refusal leaves the active blocking decision and account state intact" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @other.public_id, state: "pending_approval",
    )
    the_case.update!(state: "active")
    before = the_case.reload.attributes
    before_client = @client.reload.attributes
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability:, reason_code: "bootstrap",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    headers = as_staff_headers(@operator, host: @host, select_available_org_persona: true)
    post base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
         params: { reason: "revoked" }, headers: headers, as: :json

    assert_response :service_unavailable
    assert_equal before, the_case.reload.attributes
    assert_equal before_client, @client.reload.attributes
    assert_equal 0, EnforcementEvent.where(case_public_id: the_case.public_id).count
  end
end
