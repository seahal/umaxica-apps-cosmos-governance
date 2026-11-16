# frozen_string_literal: true

require "test_helper"

class Base::App::RpRootFeatureRefusalTest < ActionDispatch::IntegrationTest
  test "a valid local RP session cannot issue or register credentials without Access authority" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    original_counts = [ClientSecretCredential.count, ClientSecretIssuance.count, ClientTotpCredential.count,
                       ClientPasskey.count, RpStepUpState.count,]

    as_rp_cell("base-app-ww") do
      headers = as_user_headers(actor, host:)
      session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      pt = ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("path_target_token", 32),
        digest: "SHA256", serializer: JSON, url_safe: true,
      ).generate(
        {
          "flow" => "step_up.bootstrap",
          "surface" => "app",
          "session_nonce" => session_id,
          "pt" => "/identity/telephones",
        },
        purpose: :path_target, expires_in: 15.minutes,
      )
      get "/secrets", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
      post "/secrets", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
      get "/verification", params: { ri: "jp", scope: "settings_secret_credential" }, headers: headers

      assert_response :service_unavailable
      post "/verification", params: { ri: "jp", scope: "settings_telephone", pt: pt }, headers: headers

      assert_response :service_unavailable
      assert_equal "application/json", response.media_type
      assert_equal({ "error" => I18n.t("auth.rp_feature_unavailable") }, response.parsed_body)
      assert_includes response.headers["Cache-Control"], "no-store"

      [
        [:get, "/secrets/new"],
        [:get, "/secrets/unavailable"],
        [:get, "/secrets/unavailable/edit"],
        [:patch, "/secrets/unavailable"],
        [:delete, "/secrets/unavailable"],
        [:get, "/secret_issuances/unavailable"],
        [:patch, "/secret_issuances/unavailable"],
        [:delete, "/secret_issuances/unavailable"],
        [:post, "/secret_issuances/unavailable/reattempt"],
        [:post, "/secret_issuances/unavailable/presentation"],
      ].each do |method, path|
        process(method, path, params: { ri: "jp" }, headers: headers)

        assert_response :service_unavailable, "#{method.upcase} #{path} must fail closed"
        assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
      end
    end

    assert_equal original_counts, [ClientSecretCredential.count, ClientSecretIssuance.count, ClientTotpCredential.count,
                                   ClientPasskey.count, RpStepUpState.count,]
  end
end
