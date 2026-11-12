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
      get "/secrets", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
      post "/secrets", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
      get "/verification", params: { ri: "jp", scope: "settings_secret_credential" }, headers: headers

      assert_response :service_unavailable
      get "/verification/setup", params: { ri: "jp", scope: "settings_secret_credential" }, headers: headers

      assert_response :service_unavailable
      post "/verification/setup", params: { ri: "jp", scope: "settings_passkey" }, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
    end
    assert_equal original_counts, [ClientSecretCredential.count, ClientSecretIssuance.count, ClientTotpCredential.count,
                                   ClientPasskey.count, RpStepUpState.count,]
  end
end
