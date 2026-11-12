# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  test "renders the public root without retired sign-in navigation" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_root_url(ri: "jp")

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
    assert_equal "Base App", inertia_props.fetch("heading")
    assert_nil inertia_props.dig("chrome", "account_navigation")
  end

  test "a malformed RP credential is cleared before public Home renders anonymously" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_cookie = OidcRpBrowserCredentialContract::ACCESS_COOKIE
    session_cookie = OidcRpBrowserCredentialContract::SESSION_COOKIE
    cookies[access_cookie] = "malformed-access-credential"
    cookies[session_cookie] = "stale-local-session"

    get base_app_root_url(ri: "jp")

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
    assert_nil inertia_props.dig("chrome", "account_navigation")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")

    set_cookie_header = Array(response.headers["Set-Cookie"]).join("\n")
    [access_cookie, session_cookie].each do |cookie_name|
      deletion = set_cookie_header.lines.find { |line| line.start_with?("#{cookie_name}=") }

      assert_predicate deletion, :present?, "expected #{cookie_name} to be detached"
      assert_match(/(?:max-age=0|expires=Thu, 01 Jan 1970)/i, deletion)
    end
  end

  test "preserves an incoming request id through Rails request and response handling" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    request_id = "550e8400-e29b-41d4-a716-446655440000"

    get base_app_root_url(ri: "jp"), headers: { "X-Request-ID" => request_id }

    assert_response :success
    assert_equal request_id, request.request_id
    assert_equal request_id, response.headers.fetch("X-Request-Id")
  end

  test "generates a request id when the request does not provide one" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_root_url(ri: "jp")

    assert_response :success
    assert_predicate request.request_id, :present?
    assert_equal request.request_id, response.headers.fetch("X-Request-Id")
  end

  test "renders the control-plane root for the us region" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_root_url(ri: "us")

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "keeps extra request context on the control-plane root instead of leaving the host" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_root_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo")

    assert_response :success
    assert_nil response.location
  end

  test "renders Home for an unknown region after region canonicalization" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_root_url(ri: "xx")

    assert_response :found
    assert_redirected_to base_app_root_url(ri: "jp")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "renders Home for a missing region after region canonicalization" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get "/"

    assert_response :found
    assert_redirected_to base_app_root_url(ri: "jp")
    follow_redirect!

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "renders the control-plane root when extra preference params are supplied" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "authenticated regional Home returns 403 without redirect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    http_headers_4 = as_user_headers(clients(:one), host: host)
    get base_app_root_url(ri: "jp"), headers: http_headers_4

    assert_response :forbidden
    assert_nil response.location
  end

  test "authenticated Home without region returns 403 after region canonicalization" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    http_headers_3 = as_user_headers(clients(:one), host: host)
    get "/", headers: http_headers_3

    assert_response :found
    assert_redirected_to base_app_root_url(ri: "jp")
    follow_redirect!(headers: http_headers_3)

    assert_response :forbidden
    assert_nil response.location
  end
  test "authenticated Home answers 403 as a rendered response, not a raised exception" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    controller_exception =
      capture_controller_exception do
        http_headers_2 = as_user_headers(clients(:one), host: host)
        get(
          base_app_root_url(ri: "jp"), headers: http_headers_2,
        )
      end

    assert_response :forbidden
    assert_nil controller_exception
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "authenticated Home answers a JSON request with the JSON 403 document" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    http_headers_1 = as_user_headers(clients(:one), host: host)
    get base_app_root_url(ri: "jp", format: :json), headers: http_headers_1

    assert_response :forbidden
    assert_equal({ "status" => 403, "error" => "Forbidden" }, response.parsed_body)
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "authenticated Home answers an HTML request with the plain 403 text" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    http_headers_0 = as_user_headers(clients(:one), host: host)
    get base_app_root_url(ri: "jp"), headers: http_headers_0

    assert_response :forbidden
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("errors.messages.not_authorized"), response.body
  end

  test "anonymous Dashboard remains unauthorized without a sign-in route" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_dashboard_url(ri: "jp")

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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::App::RootsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Base::App::RootsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationCookieName.access] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationCookieName.refresh] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(FOREIGN_APP FOREIGN_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::RootsControllerTest
  private

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
