# frozen_string_literal: true

require "test_helper"

class AppRailsEdgeOwnershipContractTest < ActiveSupport::TestCase
  ROUTE_CASES = begin
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [
      [hosts.base_service.host, :get, "/", "base/app/roots", "index"],
      [hosts.base_service.host, :get, "/api/v0/preferences/theme", "base/app/api/v0/preferences/themes", "show"],
      [hosts.base_service.host, :patch, "/api/v0/preferences/theme", "base/app/api/v0/preferences/themes", "update"],
      [hosts.tech_staff.host, :get, "/", "tech/org/roots", "index"],
      [hosts.tech_staff.host, :get, "/health", "tech/org/healths", "show"],
    ]
  end.freeze

  EXPECTED_DRAWS = %w(base tech mission flipper blazer pghero swagger coverband).freeze

  test "the router draws only Governance and retained operator tools" do
    draws = Rails.root.join("config/routes.rb").read.scan(/^\s*draw\s+:([a-z_]+)/).flatten

    assert_equal EXPECTED_DRAWS, draws
  end

  test "Base and Tech retain their own Rails routes" do
    ROUTE_CASES.each do |host, method, path, expected_controller, expected_action|
      route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

      assert_equal expected_controller, route.fetch(:controller), "#{method.upcase} #{host}#{path}"
      assert_equal expected_action, route.fetch(:action), "#{method.upcase} #{host}#{path}"
    end
  end

  test "state-changing preference routes keep their declared verbs" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/api/v0/preferences/theme", method: :put)
    end
  end
end
