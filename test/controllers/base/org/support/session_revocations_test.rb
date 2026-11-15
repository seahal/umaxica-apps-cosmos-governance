# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::SessionRevocationsTest < ActionDispatch::IntegrationTest
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

  test "support routes preserve ORG ownership and do not expose revocation through DELETE" do
    app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{app_host}/support/clients/#{@client.public_id}/revocations", method: :post,
      )
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{@host}/support/clients/#{@client.public_id}/revocations",
        method: :delete,
      )
    end
  end

  test "support policy requires read before revoke and scopes its target to a Client" do
    assert_not SupportClientPolicy.new(@client, user: @operator).apply(:revoke_sessions?)
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert_not SupportClientPolicy.new(@client, user: @operator).apply(:revoke_sessions?)
    OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap", capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert SupportClientPolicy.new(@client, user: @operator).apply(:revoke_sessions?)
    assert_not SupportClientPolicy.new(@other, user: @operator).apply(:show?)
  end

  test "Governance account listing remains available while Access-owned session reads and revocation fail closed" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability:, reason_code: "bootstrap",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    headers = as_staff_headers(@operator, host: @host, select_available_org_persona: true)
    before = @client.reload.attributes
    before_audits = Chronicle.where(action: "support.session.revoked").count

    get base_org_support_client_url(@client.public_id, ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    assert_nil response.location
    assert_not_includes response.body, @client.public_id

    get base_org_support_client_revocation_url(@client.public_id, SecureRandom.uuid, ri: "jp", host: @host),
        headers: headers

    assert_response :not_found
    assert_nil response.location

    get base_org_support_clients_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_includes response.body, @client.public_id

    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "security_incident", ticket_id: "ticket-1", operation_id: SecureRandom.uuid },
         headers: headers

    assert_response :service_unavailable
    assert_equal before, @client.reload.attributes
    assert_equal before_audits, Chronicle.where(action: "support.session.revoked").count
  end

  test "cross-site revocation is refused by CSRF before any Access or account mutation" do
    headers = as_staff_headers(@operator, host: @host, select_available_org_persona: true)
    before = @client.reload.attributes
    before_audits = Chronicle.where(action: "support.session.revoked").count
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      post(
        base_org_support_client_revocations_url(@client.public_id, host: @host),
        params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
        headers: headers.merge("Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example"),
      )
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    # This browser HTML endpoint uses Rails' 422 CSRF refusal, before the owner API.
    assert_response :unprocessable_content
    assert_equal before, @client.reload.attributes
    assert_equal before_audits, Chronicle.where(action: "support.session.revoked").count
  end
end
