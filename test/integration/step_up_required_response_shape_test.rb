# typed: false
# frozen_string_literal: true

require "test_helper"

# A protected RP resource returns the RFC 9470 challenge only after its resource policy allows the
# request. Full-document requests get an explicit entry link; scripted requests get localized text.
class StepUpRequiredResponseShapeTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  STEP_UP_CHALLENGE_HEADER = 'Bearer error="insufficient_user_authentication", ' \
                             'error_description="step-up authentication is required", ' \
                             'acr_values="urn:umaxica:base:step-up", max_age="300"'

  setup do
    @test_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      birthdate: Date.new(1990, 1, 1),
    )
    ClientPasskey.create!(
      user: @test_client,
      webauthn_id: "step-up-response-client-#{SecureRandom.hex(8)}",
      public_key: "step-up-response-client-public-key",
      sign_count: 0,
      description: "Step-up response test Passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    @test_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    2.times do |index|
      OperatorPasskey.create!(
        staff: @test_operator,
        webauthn_id: "step-up-response-#{index}-#{SecureRandom.hex(8)}",
        external_id: SecureRandom.uuid,
        public_key: "step-up-response-public-key-#{index}",
        sign_count: 0,
        description: "Step-up response test Passkey #{index + 1}",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
  end

  test "an authorized APP document receives a challenge only for its own existing Passkey" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(@test_client, host:).merge(
      "Accept" => "text/html", "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
    )
    passkey = @test_client.client_passkeys.active.sole
    get base_app_identity_passkey_url(SecureRandom.alphanumeric(21), ri: "jp", host:), headers: headers

    assert_response :not_found
    assert_nil response.headers["WWW-Authenticate"]

    get base_app_identity_passkey_url(passkey.public_id, ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_select "h1", I18n.t("auth.step_up.challenge.title")
    assert_select "a[href=?]", base_app_verification_path(
      return_target: base_app_identity_passkey_path(passkey.public_id), ri: "jp",
    ), I18n.t("actions.continue")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an APP Inertia request receives a challenge without external navigation" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(@test_client, host:).merge(
      "Accept" => "text/html", "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version,
    )
    passkey = @test_client.client_passkeys.active.sole

    get base_app_identity_passkey_url(passkey.public_id, ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("auth.step_up.challenge.description"), response.body
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an authorized ORG document receives the same bound challenge" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    headers = as_staff_headers(@test_operator, host:).merge(
      "Accept" => "text/html", "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
    )
    passkey = @test_operator.operator_passkeys.active.first
    get base_org_identity_passkey_url(SecureRandom.alphanumeric(21), ri: "jp", host:), headers: headers

    assert_response :not_found
    assert_nil response.headers["WWW-Authenticate"]

    get base_org_identity_passkey_url(passkey.external_id, ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_select "h1", I18n.t("auth.step_up.challenge.title")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an ORG scripted request receives localized plain text and the challenge" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    headers = as_staff_headers(@test_operator, host:).merge(
      "Accept" => "text/html",
      "X-Requested-With" => "XMLHttpRequest",
    )
    passkey = @test_operator.operator_passkeys.active.first

    get base_org_identity_passkey_url(passkey.external_id, ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("auth.step_up.challenge.description"), response.body
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
  end

  test "an APP actor cannot create a withdrawal flow while Access admission is unavailable" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(actor, host:).merge("Accept" => "application/json")

    assert_no_difference "ClientWithdrawalFlow.count" do
      patch base_app_identity_withdrawal_url(ri: "jp", host:), params: { ack_schedule_purge: "1" }, headers:, as: :json
    end

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.parsed_body.fetch("error")
  end
end
