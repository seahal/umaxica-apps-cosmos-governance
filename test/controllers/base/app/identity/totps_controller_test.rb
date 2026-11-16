# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::TotpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @credential = ClientTotpCredential.create_for_user!(
      user: @client,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "Mobile authenticator",
      private_key: ROTP::Base32.random_base32,
    )
    @headers = as_user_headers(@client, host: @host)
  end

  test "credential inventory is readable but its detail refuses without locally supported step-up evidence" do
    get base_app_identity_totps_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal @credential.public_id, inertia_props.fetch("totps").fetch(0).fetch("public_id")

    get base_app_identity_totp_url(@credential.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_not_includes response.body, "Mobile authenticator"
  end
end
