# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "Base app public endpoints respond on the control-plane surface" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    host! host

    get "/?ri=jp", headers: { "Host" => host }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/robots.txt", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    get "/sitemap.xml", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    post "/csp-violation-report", headers: { "Host" => host }

    assert_response :success
  end

  test "Base public host family renders the control-plane home" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [
      [hosts.base_service.host, "base/app/roots/index"],
      [hosts.base_corporate.host, "base/com/roots/index"],
      [hosts.base_staff.host, "base/org/roots/index"],
    ].each do |host, component|
      host! host

      get "/?ri=jp", headers: { "Host" => host }

      assert_response :success
      assert_equal component, inertia_component
    end
  end
end
