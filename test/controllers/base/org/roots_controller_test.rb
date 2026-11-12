# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  test "renders the control-plane root for a regional request" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_root_url(ri: "jp")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
    assert_equal "Base Org", inertia_props.fetch("heading")
  end

  test "renders the control-plane root for the us region" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_root_url(ri: "us")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "keeps extra request context on the control-plane root instead of leaving the host" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_root_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo")

    assert_response :success
    assert_nil response.location
  end

  test "renders Home for an unknown region after region canonicalization" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_root_url(ri: "xx")

    assert_response :found
    assert_redirected_to base_org_root_url(ri: "jp")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/org/roots/index", inertia_component
  end

  test "renders Home for a missing region after region canonicalization" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get "/"

    assert_response :found
    assert_redirected_to base_org_root_url(ri: "jp")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/org/roots/index", inertia_component
  end

  test "renders the control-plane root when extra preference params are supplied" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "authenticated Home returns 403 without redirect" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    staff = operators(:one)

    http_headers_1 = as_staff_headers(staff, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    get base_org_root_url(ri: "jp"),
        headers: http_headers_1

    assert_not_equal 301, response.status
    assert_not_equal "https://jp.umaxica.org/", response.location
    assert_response :forbidden
    assert_nil response.location
  end
  test "authenticated Home answers 403 as a rendered response, not a raised exception" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    controller_exception =
      capture_controller_exception do
        http_headers_0 = as_staff_headers(operators(:one), host: host)
        get(
          base_org_root_url(ri: "jp"), headers: http_headers_0,
        )
      end

    assert_response :forbidden
    assert_nil controller_exception
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "anonymous Dashboard is unauthorized without a sign-in route" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_dashboard_url(ri: "jp")

    assert_response :unauthorized
    assert_nil response.location
    assert_equal "no-store", response.headers["Cache-Control"]
  end
  private

  # The controller's own instrumentation reports an exception that escaped the action; the 404
  # boundary is ordinary control flow and must not depend on the exceptions app.
  def capture_controller_exception(&)
    captured = nil
    callback = ->(*, payload) { captured = payload[:exception] if payload.key?(:exception) }
    ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller", &)
    captured
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::Org::RootsControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::RootsControllerTest
  private

  def set_access_cookie(token)
    cookies[AuthenticationCookieName.access] = token
  end

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "AUTH"
      else
        "BASE"
      end
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
