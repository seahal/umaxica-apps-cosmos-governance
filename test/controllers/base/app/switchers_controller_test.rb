# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::SwitchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @token = seed_rp_browser_session(
      client: OidcClientRegistry.find!("base-app-ww"), actor: @user,
      sid: SecureRandom.uuid, absolute_expires_at: 1.hour.from_now,
    )
  end

  test "unauthenticated identity cannot access switcher" do
    get base_app_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "selector-only identity cannot access switcher" do
    http_headers_6 = as_user_headers(@user, host: @host, select_available_app_persona: false)
    get base_app_switcher_url(host: @host, ri: "jp"), headers: http_headers_6

    assert_redirected_to base_app_selector_path(ri: "jp")
  end

  test "authenticated identity can access switcher show" do
    select_token!
    http_headers_5 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_app_switcher_url(host: @host), headers: http_headers_5, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @token.op_session_binding.sid,],
    )
    rp_session = RpBaseAppSession.find_by!(public_id: rp_session_id)

    assert RpBaseAppSessionSelection.exists?(rp_session_id: rp_session.id)
  end

  test "authenticated identity can access switcher update" do
    select_token!
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: @token,
    ).selectable_candidates.first
    http_headers_4 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    patch base_app_switcher_url(host: @host), headers: http_headers_4, params: candidate.fetch(:public), as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @token.op_session_binding.sid,],
    )
    rp_session = RpBaseAppSession.find_by!(public_id: rp_session_id)
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id)

    assert_equal candidate.fetch(:public).fetch(:account_public_id), selection.account_public_id
  end

  test "switcher update follows html redirect on success" do
    select_token!
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: @token,
    ).selectable_candidates.first

    http_headers_3 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    patch base_app_switcher_url(host: @host, ri: "jp"), headers: http_headers_3, params: candidate.fetch(:public)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @token.op_session_binding.sid,],
    )
    rp_session = RpBaseAppSession.find_by!(public_id: rp_session_id)

    assert RpBaseAppSessionSelection.exists?(rp_session_id: rp_session.id)
  end

  test "switcher update renders invalid switch error as json" do
    select_token!
    current_context = current_context_snapshot

    http_headers_2 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    patch base_app_switcher_url(host: @host), headers: http_headers_2, params: invalid_switch_params, as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_switch", response.parsed_body.fetch("status")
    assert_context_unchanged!(current_context)
  end

  test "switcher update renders invalid switch error as html" do
    select_token!
    current_context = current_context_snapshot

    http_headers_1 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    patch base_app_switcher_url(host: @host, ri: "jp"), headers: http_headers_1, params: invalid_switch_params

    assert_response :unprocessable_content
    assert_equal "base/app/switchers/show", inertia_component
    assert_predicate inertia_props.fetch("error"), :present?
    assert_context_unchanged!(current_context)
  end

  test "switcher show renders the inertia page as html" do
    select_token!

    http_headers_0 =
      begin
        as_user_headers(
          @user,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_app_switcher_url(host: @host, ri: "jp"), headers: http_headers_0

    assert_response :success
    assert_equal "base/app/switchers/show", inertia_component
    assert_equal "Switcher", inertia_props.fetch("title")
    assert_equal I18n.t("actions.up", locale: :ja), inertia_props.dig("up_link", "label")
    assert_equal base_app_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @token.op_session_binding.sid,],
    )
    rp_session = RpBaseAppSession.find_by!(public_id: rp_session_id)

    assert RpBaseAppSessionSelection.exists?(rp_session_id: rp_session.id)
  end

  private

  def select_token!
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.select(
      surface: :app, principal: @user, session: @token,
      params: {
        account_public_id: bootstrap.account.public_id,
        organization_public_id: bootstrap.collective.public_id,
        organization_unit_public_id: bootstrap.unit.public_id,
        avatar_public_id: bootstrap.avatar&.public_id,
      },
    )
  end

  def current_context_snapshot
    RpBaseAppSessionSelection.find_by!(rp_session_id: @token.id).slice(
      "account_public_id", "organization_public_id", "organization_unit_public_id", "avatar_public_id",
    )
  end

  def assert_context_unchanged!(current_context)
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: @token.id)

    assert_equal current_context["account_public_id"], selection.account_public_id
    assert_equal current_context["organization_public_id"], selection.organization_public_id
    assert_equal current_context["organization_unit_public_id"], selection.organization_unit_public_id
    assert_equal current_context["avatar_public_id"], selection.avatar_public_id
  end

  def invalid_switch_params
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: @token,
    ).selectable_candidates.first

    candidate.fetch(:public).merge(avatar_public_id: "unknown-avatar")
  end
  private

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
class Base::App::SwitchersControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::SwitchersControllerTest
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
