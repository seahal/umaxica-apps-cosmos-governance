# typed: false
# frozen_string_literal: true

require "test_helper"

class CycleCloseAuthenticatedRootsTest < ActionDispatch::IntegrationTest
  ROOTS = [
    ["PUBLIC_BASE_SERVICE_URL", "base.app.localhost"],
    ["PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"],
    ["PUBLIC_BASE_STAFF_URL", "base.org.localhost"],
    ["PUBLIC_TECH_STAFF_URL", "tech.org.localhost"],
  ].freeze

  test "Governance roots answer on their host and do not open-redirect" do
    ROOTS.each do |env_key, fallback|
      host = ENV.fetch(env_key, fallback)
      get "/", params: { ri: "jp" }, headers: { "Host" => host }

      assert_includes [200, 302, 303, 401], response.status, host
      next unless response.redirect?

      location = URI.parse(response.location)

      assert_not_equal "evil.example", location.host, host
      assert_not_includes location.to_s, "://evil.", host
    end
  end

  test "anonymous Base Dashboard is unauthorized and the retired lobby remains absent" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    get "/dashboard", params: { ri: "jp" }, headers: { "Host" => host }

    assert_response :unauthorized, "/dashboard"
    assert_nil response.location

    get "/lobby", params: { ri: "jp" }, headers: { "Host" => host }

    assert_response :not_found, "/lobby"
  end

  test "an unrecognized ri does not redirect off-host" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    get "/", params: { ri: "https://evil.example" }, headers: { "Host" => host }

    assert_includes [200, 302, 303, 400], response.status
    if response.redirect?
      assert_not_includes response.location, "evil.example"
    end
  end
end
