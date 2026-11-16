# frozen_string_literal: true

require "test_helper"

# R5-WU17 role ingress boundary: a role process answers 404 for a controller it does not own,
# before any controller callback runs, and serves its own and shared controllers normally.
class RuntimeRoleRouteGuardTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "a role process refuses another role's page before any callback" do
    with_runtime_role("rp-base-org-ww") do
      get base_app_identity_birthdate_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    end

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["Set-Cookie"]
  end

  test "a role process serves a shared path" do
    with_runtime_role("rp-base-app-ww") do
      get base_app_api_v0_health_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    end

    assert_response :ok
  end

  test "the owning role reaches its own page" do
    with_runtime_role("rp-base-app-ww") do
      get base_app_identity_birthdate_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    end

    # Unauthenticated: the page's own authentication answers, not the role guard.
    assert_not_equal 404, response.status
  end

  test "Base Org RP role serves its sign entry but Base App RP role does not" do
    org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    with_runtime_role("rp-base-org-ww") do
      get "/sign", params: { ri: "jp" }, headers: { "Host" => org_host }

      assert_response :success
    end

    app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    with_runtime_role("rp-base-app-ww") do
      get "/sign", params: { ri: "jp" }, headers: { "Host" => app_host }

      assert_response :success
      get "/sign", params: { ri: "jp" }, headers: { "Host" => org_host }

      assert_response :not_found
    end
  end

  # Auth/Visa URL removal retires the external logout-token receiver with the sign-in path.
  test "a closed RP cell refuses browser pages and has no back-channel logout route" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    with_runtime_role("rp-base-app-ww", admission: "closed") do
      get "/accounts", params: { ri: "jp" }, headers: { "Host" => host }

      assert_response :not_found

      post "/oidc/closures", headers: { "Host" => host }

      assert_response :not_found
    end
  end

  private

  # The role is process-wide configuration; each parallel worker is its own process.
  def with_runtime_role(name, admission: "open")
    previous = ENV.to_h.slice("UMAXICA_RUNTIME_ROLE", "UMAXICA_RP_BROWSER_ADMISSION")
    ENV["UMAXICA_RUNTIME_ROLE"] = name
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = admission
    yield
  ensure
    %w(UMAXICA_RUNTIME_ROLE UMAXICA_RP_BROWSER_ADMISSION).each do |key|
      previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key)
    end
  end
end
