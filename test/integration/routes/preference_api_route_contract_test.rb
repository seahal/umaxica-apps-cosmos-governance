# typed: false
# frozen_string_literal: true

require "test_helper"

# Base owns the interactive browser Preference API on each of its three surfaces.
class PreferenceApiRouteContractTest < ActionDispatch::IntegrationTest
  SURFACES = begin
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [
      [hosts.base_service.host, "base/app"],
      [hosts.base_corporate.host, "base/com"],
      [hosts.base_staff.host, "base/org"],
    ]
  end.freeze

  test "Base serves the preference API with GET and PATCH only" do
    SURFACES.each do |host, surface|
      %w(theme cookie).each do |resource|
        url = "https://#{host}/api/v0/preferences/#{resource}"
        controller = (resource == "theme") ? "themes" : "cookies"

        assert_equal(
          { controller: "#{surface}/api/v0/preferences/#{controller}", action: "show" },
          Rails.application.routes.recognize_path(url, method: :get).slice(:controller, :action),
        )
        assert_equal(
          { controller: "#{surface}/api/v0/preferences/#{controller}", action: "update" },
          Rails.application.routes.recognize_path(url, method: :patch).slice(:controller, :action),
        )
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path(url, method: :put)
        end
      end
    end
  end

  test "retired web preference paths are unroutable on Base" do
    SURFACES.each do |host, _surface|
      %w(theme cookie).each do |resource|
        %i(get patch put).each do |method|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("https://#{host}/web/v0/#{resource}", method: method)
          end
        end
      end
    end
  end
end
