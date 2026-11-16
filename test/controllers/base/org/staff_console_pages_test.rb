# frozen_string_literal: true

require "test_helper"

class Base::Org::StaffConsolePagesTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    2.times do
      OperatorPasskey.create!(
        staff: @operator, webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid, public_key: "test-public-key",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    @headers = as_staff_headers(@operator, host: @host)
  end

  test "local consoles deny missing capabilities through real policy and authenticated HTTP" do
    [base_org_audit_index_url(ri: "jp", host: @host), base_org_billing_index_url(ri: "jp", host: @host),
     base_org_iam_index_url(ri: "jp", host: @host), base_org_system_index_url(ri: "jp", host: @host),
     base_org_settings_url(ri: "jp", host: @host),].each do |url|
      get url, headers: @headers, as: :json

      assert_response :forbidden
    end
    assert_not OrgConsolePolicy.new(:org_console, user: @operator).apply(:support?)
    assert_not OrgConsolePolicy.new(:org_console, user: @operator).apply(:iam?)
  end

  test "IAM landing remains readable with its Governance capability" do
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    assert_equal "base/org/iam/index", inertia_component
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "consoles with no authoritative source stay denied even to every capability holder" do
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator, capabilities: OperatorCapabilityGrant::CAPABILITIES,
      ticket_id: "TEST-1", expires_at: 1.day.from_now,
    )
    [base_org_audit_index_url(ri: "jp", host: @host), base_org_billing_index_url(ri: "jp", host: @host),
     base_org_system_index_url(ri: "jp", host: @host), base_org_settings_url(ri: "jp", host: @host),].each do |url|
      get url, headers: @headers, as: :json

      assert_response :forbidden
    end
  end

  test "Support landing renders only the areas allowed by Governance capabilities" do
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert OrgConsolePolicy.new(:org_console, user: @operator).apply(:support?)
    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal "base/org/support/index", inertia_component
    assert_empty inertia_props.fetch("sections").sole.fetch("items")
  end

  test "selected local RP session renders its Governance identity without changing selection" do
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    pairs = @headers.fetch("Cookie").split("; ").to_h { |pair| pair.split("=", 2) }
    session = RpBaseOrgSession.includes(:op_session_binding).find_by!(public_id: Rack::Utils.unescape(pairs.fetch(OidcRpBrowserCredentialContract::SESSION_COOKIE)))
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: session)
    selection = RpBaseOrgSessionSelection.find_by!(rp_session_id: session.id)
    before = selection.reload.attributes
    get base_org_dashboard_url(ri: "jp", host: @host), headers: @headers, as: :json

    assert_response :success
    assert_equal "base/org/dashboards/show", inertia_component
    assert_equal before, selection.reload.attributes
    assert_equal 1, RpBaseOrgSessionSelection.where(rp_session_id: session.id).count
  end

  test "an anonymous browser cannot enter a protected administration console" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end
end
