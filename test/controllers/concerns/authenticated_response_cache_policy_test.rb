# typed: false
# frozen_string_literal: true

require "test_helper"

# Authenticated pages must not outlive the session in a browser: an authenticated HTML or Inertia
# response is `Cache-Control: no-store` (so neither the HTTP cache nor the back/forward cache keeps
# it), and a response that ends a session tells Inertia to clear its encrypted history. Ordinary
# authenticated navigation does not clear history. Base is a Global policy root, so public pages and
# JSON endpoints that make no cache decision are `no-store` too, from `DefaultNoStore`
# (adr/global-and-publishing-default-no-store-policy.md) rather than from the authenticated-page rule.
class AuthenticatedResponseCachePolicyTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = configured_host(:base_service)
    host! @host
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
  end

  test "an authenticated HTML page is no-store" do
    get base_app_identity_url(ri: "jp", host: @host), headers: begin
      as_user_headers(@user, host: @host)
    end

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_no_store
  end

  # Rack adds a validator to the page, and a 304 is produced only after the action ran. A
  # conditional request therefore cannot skip the credential check: without a valid credential the
  # matching validator earns the sign-in redirect, never a 304.
  test "a matching validator does not let a conditional request bypass authentication" do
    headers = as_user_headers(@user, host: @host)
    get base_app_identity_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert_no_store
    validator = response.headers.fetch("ETag")

    get base_app_identity_url(ri: "jp", host: @host), headers: host_headers(@host).merge("If-None-Match" => validator)

    assert_response :unauthorized
    assert_nil response.location

    session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: session_id)
    rp_session.op_session_binding.revoke!
    get base_app_identity_url(ri: "jp", host: @host), headers: headers.merge("If-None-Match" => validator)

    assert_not_equal 304, response.status
    assert_response :unauthorized
  end

  test "an authenticated Inertia visit is no-store" do
    get base_app_identity_url(ri: "jp", host: @host), headers: begin
      as_user_headers(@user, host: @host)
    end
    version = inertia_page.fetch("version")

    get base_app_identity_url(ri: "jp", host: @host),
        headers: begin
          rp_headers = as_user_headers(@user, host: @host)
          rp_headers
        end.merge("X-Inertia" => "true", "X-Inertia-Version" => version.to_s)

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_no_store
  end

  test "ordinary authenticated navigation does not clear Inertia history" do
    get base_app_identity_url(ri: "jp", host: @host), headers: begin
      as_user_headers(@user, host: @host)
    end

    assert_response :success
    # inertia_rails omits clearHistory from the page object when it is false.
    assert_not inertia_page.fetch("clearHistory", false)
  end

  test "an anonymous public HTML page carries the Global default no-store" do
    get edit_base_app_preference_cookie_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "an open page answered for a signed-in user is no-store" do
    as_rp_cell("base-app-ww") do
      get edit_base_app_preference_cookie_url(ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

      assert_response :success
      assert_no_store
    end
  end

  test "an authenticated JSON response carries the Global default no-store" do
    get base_app_selector_url(ri: "jp", host: @host, format: :json), headers: begin
      as_user_headers(@user, host: @host)
    end

    assert_equal "application/json", response.media_type
    assert_no_store
  end

  # Stale credentials on an :open page are detached and the request continues anonymously. If it
  # arrived as an Inertia visit, the signed-in pages are still in that document's history, so the
  # anonymous page that replaces them must clear it.
  test "detaching stale credentials clears Inertia history on the page that follows" do
    headers = as_user_headers(@user, host: @host)
    session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: session_id)
    rp_session.op_session_binding.revoke!

    get base_app_root_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert inertia_page.fetch("clearHistory")
  end

  private

  def fetch_csrf_token(path, headers: {})
    ActionController::Base.allow_forgery_protection = true
    get(path, headers: headers)
    csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] ||
      response.body[/name="authenticity_token" value="([^"]+)"/, 1]

    assert_predicate csrf_token, :present?, "expected a CSRF token in the response"
    csrf_token
  ensure
    ActionController::Base.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection
  end

  def assert_no_store
    assert_includes response.headers["Cache-Control"].to_s.split(",").map(&:strip), "no-store",
                    "expected no-store, got #{response.headers["Cache-Control"].inspect}"
  end

  def same_host?(location)
    URI.parse(location).host.in?([nil, @host])
  end

  # DAMP local helper copy, as in the other Base controller tests.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
