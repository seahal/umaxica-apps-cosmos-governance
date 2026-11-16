# frozen_string_literal: true

require "test_helper"

class Base::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @client = clients(:one)
    @headers = as_user_headers(@client, host: @host, select_available_app_persona: false)
    session_id = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    @rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: session_id)
    access_token = jwt_access_token_for(@client, host: @host)
    @headers["Cookie"] = [
      @headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
    ].join("; ")
    @headers["HTTP_COOKIE"] = @headers.fetch("Cookie")
  end

  test "Base App exposes only its sign out confirmation, completion and logout receiver paths" do
    routes =
      Rails.application.routes.routes.filter_map do |route|
        next unless route.defaults[:controller].to_s.start_with?("base/app/sign_outs", "base/app/oidc/closures")

        [route.verb, route.path.spec.to_s, route.defaults[:controller], route.defaults[:action]]
      end

    assert_includes routes, ["GET", "/sign/out(.:format)", "base/app/sign_outs", "show"]
    assert_includes routes, ["GET", "/sign/out/new(.:format)", "base/app/sign_outs", "new"]
    assert_includes routes, ["GET", "/sign/out/edit(.:format)", "base/app/sign_outs", "edit"]
    assert_includes routes, ["POST", "/sign/out(.:format)", "base/app/sign_outs", "create"]
    assert_includes routes, ["GET", "/sign/out/completion(.:format)", "base/app/sign_outs", "show"]
    assert_includes routes, ["POST", "/oidc/closures(.:format)", "base/app/oidc/closures", "create"]
  end

  test "the authenticated Base App header has one sign out link and no sign in link" do
    get base_app_welcome_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    navigation = inertia_props.dig("chrome", "account_navigation")

    assert navigation.fetch("signed_in")
    assert_equal I18n.t("layouts.shared.account_navigation.label"), navigation.fetch("label")
    assert_equal(
      [{ "label" => I18n.t("layouts.shared.account_navigation.sign_out"), "href" => "/sign/out/new?ri=jp" }],
      navigation.fetch("links"),
    )
  end

  test "sign out pages hide account navigation and GET requests do not revoke the RP session" do
    get new_base_app_sign_out_url(host: @host, ri: "jp"), headers: @headers

    assert_response :see_other
    assert_equal edit_base_app_sign_out_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_nil @rp_session.reload.revoked_at

    get edit_base_app_sign_out_url(host: @host, ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "base/app/sign_outs/edit", inertia_component
    assert_nil inertia_props.dig("chrome", "account_navigation")
    assert_nil @rp_session.reload.revoked_at
  end

  test "POST sign out without the Rails CSRF token is refused without revoking the RP session" do
    original = Base::App::SignOutsController.allow_forgery_protection
    Base::App::SignOutsController.allow_forgery_protection = true

    post(
      base_app_sign_out_url(host: @host, ri: "jp"), params: { ri: "jp" }, headers: @headers.merge(
        "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
      ),
    )

    assert_response :unprocessable_content
    assert_nil @rp_session.reload.revoked_at
    assert_nil response.location
  ensure
    Base::App::SignOutsController.allow_forgery_protection = original
  end

  test "sign out requires the current local RP session" do
    post base_app_sign_out_url(host: @host, ri: "jp"), headers: host_headers(@host)

    assert_response :unauthorized
    assert_nil response.location
    assert_nil @rp_session.reload.revoked_at
  end

  test "RP sign out commits locally, sends Visa a no-hint request through Jump, and consumes completion once" do
    original = Base::App::SignOutsController.allow_forgery_protection
    Base::App::SignOutsController.allow_forgery_protection = true
    get(edit_base_app_sign_out_url(host: @host, ri: "jp"), headers: @headers)

    assert_response :success
    csrf_token = css_select("meta[name='csrf-token']").sole["content"]
    bound_refresh_token = [
      @rp_session.op_session_binding.sid, "test-refresh-token",
    ].join(".")
    @headers["Cookie"] = [
      @headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(bound_refresh_token)}",
    ].join("; ")
    @headers["HTTP_COOKIE"] = @headers["Cookie"]
    @headers.fetch("Cookie").split("; ").each do |pair|
      name, value = pair.split("=", 2)
      cookies[name] = Rack::Utils.unescape(value.to_s)
    end
    browser_headers = @headers.except("Cookie", "HTTP_COOKIE")
    authorization_url = nil
    revoked_token = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )

    OidcOpRevocationClient.stub(
      :revoke, ->(token:, client_id:, origin:) {
                 assert_equal RpBaseAppSession::CLIENT_ID, client_id
                 assert_equal visa_origin, origin
                 revoked_token = token
                 OidcOpRevocationClient::Result.new(outcome: :success)
               },
    ) do
      JumpRtIssuer.stub(
        :call, ->(namespace:, url:, dst:, preserve_query_keys:) {
                 authorization_url = url
                 "opaque-test-ticket"
               },
      ) do
        RedirectsJumpGatewayUrl.stub(
          :call, ->(_ticket) {
            RedirectsTargetResult.ok(kind: :external, source: :test, value: jump_destination)
          },
        ) do
          post(
            base_app_sign_out_url(host: @host, ri: "jp"), params: { ri: "jp" }, headers: browser_headers.merge(
              "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf_token,
            ),
          )
        end
      end
    end

    assert_response :see_other
    assert_equal jump_destination, response.location
    assert_predicate @rp_session.reload.revoked_at, :present?
    uri = URI.parse(authorization_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal visa_origin.host, uri.host
    assert_equal "/oidc/logout", uri.path
    assert_equal %w(client_id post_logout_redirect_uri state), query.keys.sort
    assert_equal "base-app-ww", query.fetch("client_id")
    assert_equal "/sign/out/completion", URI.parse(query.fetch("post_logout_redirect_uri")).path
    assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(query.fetch("post_logout_redirect_uri")).query).fetch("ri")
    assert_predicate query.fetch("state"), :present?
    assert_not query.key?("id_token_hint")

    cookie_names = set_cookie_names

    [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::REFRESH_COOKIE,
     OidcRpBrowserCredentialContract::SESSION_COOKIE,].each do |cookie_name|
      assert_includes cookie_names, cookie_name
    end
    assert_equal revoked_token, bound_refresh_token, "only the matching Refresh Token is revoked"

    get(
      base_app_sign_out_completion_url(host: @host, ri: "jp", state: query.fetch("state")),
      headers: host_headers(@host),
    )

    assert_response :success
    assert_equal "base/app/sign_outs/edit", inertia_component
    assert_equal I18n.t("sign.shared.sign_out.completed_title"), inertia_props.fetch("title")
    assert_nil inertia_props.dig("chrome", "account_navigation")
    assert_nil session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]

    get(
      base_app_sign_out_completion_url(host: @host, ri: "jp", state: query.fetch("state")),
      headers: host_headers(@host),
    )

    assert_response :not_found
  ensure
    Base::App::SignOutsController.allow_forgery_protection = original
  end
end
