# typed: false
# frozen_string_literal: true

require "test_helper"

# Published static GET routes must reach an HTTP boundary without an unhandled exception on the host
# they are published for. Each route is requested on the first host its own host constraint lists,
# so a 404 means the route no longer answers on its host rather than that it was sent elsewhere.
class StaticGetRouteResponseTest < ActionDispatch::IntegrationTest
  UNAVAILABLE_OWNER_PATHS = {
    "app" => %w(
      /api/v0/identity/standing /api/v0/identity/selection
      /api/v0/membership/app/accounts /api/v0/membership/app/organizations
      /api/v0/avatar/app/switcher /api/v0/avatar/app/dashboard-identity
      /api/v0/avatar/app/selected-image /api/v0/avatar/app/avatars /api/v0/avatar/app/groups
    ).freeze,
    "org" => %w(
      /api/v0/identity/standing /api/v0/identity/selection
      /api/v0/membership/org/accounts /api/v0/membership/org/organizations
      /api/v0/support /api/v0/iam/grants /api/v0/iam/grant-screen
      /api/v0/avatar/org/dashboard-identity /api/v0/avatar/org/switcher
      /api/v0/avatar/org/selected-avatar /api/v0/avatar/org/selected-image
    ).freeze,
  }.freeze

  SKIP = %r{/(callback|oauth|social)\b}

  test "static GET routes answer on their own host without a server error or a routing miss" do
    routes = static_get_routes_by_host

    assert_predicate routes, :any?, "no host-constrained static GET route was discovered"

    failures = []
    routes.each do |host, paths|
      host! host
      paths.each do |path|
        get(path)
        owner_paths = {
          ENV.fetch("PUBLIC_BASE_SERVICE_URL") => UNAVAILABLE_OWNER_PATHS.fetch("app"),
          ENV.fetch("PUBLIC_BASE_STAFF_URL") => UNAVAILABLE_OWNER_PATHS.fetch("org"),
        }
        if owner_paths.fetch(host, []).include?(path)
          assert_response :service_unavailable
          assert_includes response.headers["Cache-Control"], "no-store"
          next
        end
        failures << "GET #{host}#{path}: #{response.status}" if response.server_error? || response.not_found?
      rescue StandardError => e
        failures << "GET #{host}#{path}: #{e.class}: #{e.message}"
      end
    end

    assert_empty failures, failures.join("\n")
  end

  private

  def static_get_routes_by_host
    Rails.application.routes.routes
      .select { |route| route.verb == "GET" && route.constraints[:host].is_a?(Array) }
      .map { |route| [route.constraints[:host].first, route.path.spec.to_s.sub(/\(\.:format\)\z/, "")] }
      .reject { |_host, path| path.include?(":") || path.include?("*") || path.include?("(") || path.match?(SKIP) }
      .uniq
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
  end
end
