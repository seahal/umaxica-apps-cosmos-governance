# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAppBrowserRpOriginGuardTest < ActionDispatch::IntegrationTest
  test "same-origin metadata cannot authorize a preference write from a foreign Origin" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    https!

    assert_no_difference -> { AppPreference.count } do
      assert_no_difference -> { AppPreferenceChronicle.count } do
        patch(
          base_app_api_v0_preferences_theme_path(ri: "jp"),
          params: { theme: "dark" },
          headers: {
            "Accept" => "application/json",
            "Origin" => "https://attacker.example",
            "Sec-Fetch-Site" => "same-origin",
          },
          as: :json,
        )

        assert_response :unprocessable_content
        assert_equal I18n.t("errors.messages.invalid_browser_request"), response.body
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end
end
