# frozen_string_literal: true

require "test_helper"

# Base's ERB application layouts derive Preference control endpoints from the registry.
class ErbLayoutPreferenceControlsTest < ActiveSupport::TestCase
  LAYOUTS = [
    { family: "base", surface: "app", controller: Base::App::ApplicationController, host: "PUBLIC_BASE_SERVICE_URL" },
    { family: "base", surface: "org", controller: Base::Org::ApplicationController, host: "PUBLIC_BASE_STAFF_URL" },
  ].freeze

  test "Base layouts render their registered Preference controls" do
    LAYOUTS.each do |layout|
      family = layout.fetch(:family)
      surface = layout.fetch(:surface)
      expected = PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      html = layout.fetch(:controller).renderer.new("HTTP_HOST" => ENV.fetch(layout.fetch(:host)))
        .render(inline: "", layout: "#{family}/#{surface}/application")
      document = Nokogiri::HTML(html)

      theme = document.at_css("[data-controller='theme']")
      banner = document.at_css("[data-controller='cookie-banner']")

      if expected.theme_endpoint_path.nil? && expected.cookie_endpoint_path.nil?
        assert_nil theme, "#{family}/#{surface} theme control"
        assert_nil banner, "#{family}/#{surface} cookie control"
        next
      end

      assert_equal expected.theme_endpoint_path, theme["data-theme-endpoint-url-value"], "#{family}/#{surface}"
      assert_equal expected.cookie_endpoint_path, banner["data-cookie-banner-endpoint-url-value"],
                   "#{family}/#{surface}"
    end
  end
end
