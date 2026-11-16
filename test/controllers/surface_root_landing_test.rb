# typed: false
# frozen_string_literal: true

require "test_helper"

# Anonymous Base Home canonicalizes region context before rendering, as required by the
# 2026-10-25 amendment in adr/home-dashboard-authentication-boundary.md.
class SurfaceRootLandingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "base app root without a region canonicalizes the same Home path" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(host: host), headers: { "Host" => host }

    assert_response :found
    target = URI.parse(response.location)

    assert_equal "/", target.path
    assert_equal "jp", Rack::Utils.parse_query(target.query).fetch("ri")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "base app root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
    assert_equal "Base App", inertia_props.fetch("heading")
    # The landing offers no links, so it carries no text that points at them.
    assert_not inertia_props.key?("description")
    assert_not inertia_props.key?("links")
  end

  test "base com root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get base_com_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
  end

  test "base org root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get base_org_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "base app root with an unrecognized region canonicalizes the same Home path" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "zz", host: host), headers: { "Host" => host }

    assert_response :found
    target = URI.parse(response.location)

    assert_equal "/", target.path
    assert_equal "jp", Rack::Utils.parse_query(target.query).fetch("ri")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end
end
