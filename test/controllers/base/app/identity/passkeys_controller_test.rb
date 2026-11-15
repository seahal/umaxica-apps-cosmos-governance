# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @passkey = ClientPasskey.create!(
      user: @client,
      webauthn_id: SecureRandom.urlsafe_base64(32),
      public_key: "test-public-key",
      description: "Primary browser passkey",
    )
    @headers = as_user_headers(@client, host: @host)
  end

  test "passkey details refuse without locally supported step-up evidence" do
    RuntimeRole.stub(:current, "rp-base-app-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        get base_app_identity_passkey_url(@passkey.public_id, ri: "jp", host: @host), headers: @headers
      end
    end

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_not_includes response.body, @passkey.description
  end
end
