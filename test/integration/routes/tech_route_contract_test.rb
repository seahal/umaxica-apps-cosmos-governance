# typed: false
# frozen_string_literal: true

require "test_helper"

class TechRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  TECH_HOST = "tech.org.localhost"

  test "Tech exposes the operator dashboard without Auth entrypoints" do
    assert_recognizes(
      { controller: "tech/org/roots", action: "index" },
      { path: "http://#{TECH_HOST}/", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/dashboards", action: "show" },
      { path: "http://#{TECH_HOST}/dashboard", method: :get },
    )
  end

  test "Tech exposes health, revision, and CSP routes without Auth sign-out" do
    assert_recognizes(
      { controller: "tech/org/healths", action: "show" },
      { path: "http://#{TECH_HOST}/health", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/api/v0/healths", action: "show" },
      { path: "http://#{TECH_HOST}/api/v0/health.json", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/revisions", action: "show" },
      { path: "http://#{TECH_HOST}/revision", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/api/v0/revisions", action: "show" },
      { path: "http://#{TECH_HOST}/api/v0/revision.json", method: :get },
    )
    assert_recognizes(
      { controller: "tech/org/csp_violation_reports", action: "create" },
      { path: "http://#{TECH_HOST}/csp-violation-report", method: :post },
    )
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/sign", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/callback", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/sign/out", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/sign/out/completion", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/api/v0/profile", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/authorization", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/backchannel/logout", method: :post)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{TECH_HOST}/oidc/closures", method: :post)
    end
  end
end
