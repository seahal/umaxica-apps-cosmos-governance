# frozen_string_literal: true

require "test_helper"

class Base::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @headers = as_user_headers(@client, host: @host)
    session_id = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    @target = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => session_id,
        "pt" => "/identity/telephones", },
      purpose: :path_target, expires_in: 15.minutes,
    )
  end

  test "bootstrap cannot infer its missing OP root context from a local RP session" do
    get base_app_verification_setup_url(ri: "jp", host: @host),
        params: { scope: "settings_telephone", pt: @target }, headers: @headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "bootstrap refuses missing unsupported and supported choices without credentials or jobs" do
    original = [ClientPasskey.count, ClientTotpCredential.count, ClientEmail.count, RpStepUpState.count,
                RpStepUpAuditOutbox.count,]

    assert_no_enqueued_jobs do
      [nil, "", "unsupported", "passkey", "totp", "email_otp"].each do |method|
        post base_app_verification_setup_url(ri: "jp", host: @host),
             params: { scope: "settings_telephone", pt: @target, method: method }, headers: @headers

        assert_response :service_unavailable
        assert_includes response.headers["Cache-Control"], "no-store"
      end
    end
    assert_equal original, [ClientPasskey.count, ClientTotpCredential.count, ClientEmail.count, RpStepUpState.count,
                            RpStepUpAuditOutbox.count,]
  end

  test "bootstrap validates the signed target and scope before using any authority" do
    [nil, "", "invalid"].each do |target|
      get base_app_verification_setup_url(ri: "jp", host: @host),
          params: { scope: "settings_telephone", pt: target }, headers: @headers

      assert_response :bad_request
    end
    get base_app_verification_setup_url(ri: "jp", host: @host),
        params: { scope: "unsupported", pt: @target }, headers: @headers

    assert_response :bad_request
  end

  test "a registered Gov authenticator still redirects to ordinary verification" do
    ClientPasskey.create!(
      user: @client, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "bootstrap-fixture-key", sign_count: 0, description: "Bootstrap fixture",
      status_id: ClientPasskeyStatus::ACTIVE,
    )

    get base_app_verification_setup_url(ri: "jp", host: @host),
        params: { scope: "settings_telephone", pt: @target }, headers: @headers

    assert_response :see_other
    assert_equal "/verification", URI.parse(response.location).path
  end
end
