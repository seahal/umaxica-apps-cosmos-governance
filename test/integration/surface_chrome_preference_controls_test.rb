# frozen_string_literal: true

require "test_helper"

# The Base chrome decides Preference controls by surface; Base owns the browser write routes.
class SurfaceChromePreferenceControlsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences

  PAGES = [
    { family: "base",
      surface: "app",
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
      path: "/preference", },
    { family: "base",
      surface: "com",
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
      path: "/preference", },
    { family: "base",
      surface: "org",
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
      path: "/preference", },
  ].freeze

  test "page chrome exposes browser write endpoints only to Base" do
    PAGES.each do |page|
      expected = PreferenceBrowserControlsRegistry.fetch(family: page.fetch(:family), surface: page.fetch(:surface))
      host! page.fetch(:host)

      get page.fetch(:path), params: { ri: "jp" }

      label = "#{page.fetch(:family)}/#{page.fetch(:surface)}"

      assert_response :success, label
      chrome = inertia_props.fetch("chrome")

      assert_equal expected.theme_endpoint_path, chrome.dig("theme_controls", "endpoint_url"), label
      assert_equal expected.cookie_endpoint_path, chrome.dig("cookie_controls", "endpoint_url"), label
      if expected.theme_endpoint_path
        assert_match %r{\A/(?!/)}, chrome.dig("theme_controls", "endpoint_url"), label
        assert_match %r{\A/(?!/)}, chrome.dig("cookie_controls", "endpoint_url"), label
      end
    end
  end
end
