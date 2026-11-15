# frozen_string_literal: true

require "test_helper"

class Base::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = operators(:one)
    @headers = as_staff_headers(@operator, host: @host)
    session_id = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    @rp_session = RpBaseOrgSession.includes(:op_session_binding).find_by!(public_id: session_id)
    access_token = jwt_access_token_for(@operator, host: @host)
    @headers["Cookie"] = [
      @headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
    ].join("; ")
    @headers["HTTP_COOKIE"] = @headers.fetch("Cookie")
  end

  test "Base Org exposes its own sign-out, completion and logout receiver routes" do
    routes =
      Rails.application.routes.routes.filter_map do |route|
        next unless route.defaults[:controller].to_s.start_with?("base/org/sign_outs", "base/org/oidc/closures")

        [route.verb, route.path.spec.to_s, route.defaults[:controller], route.defaults[:action]]
      end

    assert_includes routes, ["GET", "/sign/out(.:format)", "base/org/sign_outs", "show"]
    assert_includes routes, ["GET", "/sign/out/new(.:format)", "base/org/sign_outs", "new"]
    assert_includes routes, ["GET", "/sign/out/edit(.:format)", "base/org/sign_outs", "edit"]
    assert_includes routes, ["POST", "/sign/out(.:format)", "base/org/sign_outs", "create"]
    assert_includes routes, ["GET", "/sign/out/completion(.:format)", "base/org/sign_outs", "show"]
    assert_includes routes, ["POST", "/oidc/closures(.:format)", "base/org/oidc/closures", "create"]
  end

  test "Base Org sign-out entry redirects to its confirmation without revoking a session" do
    get new_base_org_sign_out_url(host: @host, ri: "jp")

    assert_response :see_other
    assert_equal edit_base_org_sign_out_url(host: @host, ri: "jp"), response.location
    assert_nil @rp_session.reload.revoked_at
  end

  test "Base Org sign out revokes locally before Jump handoff and consumes one completion" do
    original = Base::Org::SignOutsController.allow_forgery_protection
    Base::Org::SignOutsController.allow_forgery_protection = true
    get(edit_base_org_sign_out_url(host: @host, ri: "jp"), headers: @headers)

    assert_response :success
    csrf_token = css_select("meta[name='csrf-token']").sole["content"]
    refresh_token = [@rp_session.op_session_binding.sid, "test-refresh-token"].join(".")
    @headers["Cookie"] = [
      @headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh_token)}",
    ].join("; ")
    @headers["HTTP_COOKIE"] = @headers["Cookie"]
    @headers.fetch("Cookie").split("; ").each do |pair|
      name, value = pair.split("=", 2)
      cookies[name] = Rack::Utils.unescape(value.to_s)
    end
    browser_headers = @headers.except("Cookie", "HTTP_COOKIE")
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host, default_scheme: "https",
    )
    authorization_url = nil
    revoked_token = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"

    OidcOpRevocationClient.stub(
      :revoke, ->(token:, client_id:, origin:) {
                 assert_equal RpBaseOrgSession::CLIENT_ID, client_id
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
          :call, ->(_ticket) { RedirectsTargetResult.ok(kind: :external, source: :test, value: jump_destination) },
        ) do
          post(
            base_org_sign_out_url(host: @host, ri: "jp"), params: { ri: "jp" }, headers: browser_headers.merge(
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
    assert_equal "base-org-ww", query.fetch("client_id")
    assert_equal "/sign/out/completion", URI.parse(query.fetch("post_logout_redirect_uri")).path
    assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(query.fetch("post_logout_redirect_uri")).query).fetch("ri")
    assert_not query.key?("id_token_hint")
    assert_equal refresh_token, revoked_token
    assert_includes set_cookie_names, OidcRpBrowserCredentialContract::ACCESS_COOKIE
    assert_includes set_cookie_names, OidcRpBrowserCredentialContract::REFRESH_COOKIE
    assert_includes set_cookie_names, OidcRpBrowserCredentialContract::SESSION_COOKIE

    get(
      base_org_sign_out_completion_url(host: @host, ri: "jp", state: query.fetch("state")),
      headers: host_headers(@host),
    )

    assert_response :success
    assert_equal "base/org/sign_outs/edit", inertia_component
    assert_equal I18n.t("sign.shared.sign_out.completed_title"), inertia_props.fetch("title")
    assert_equal I18n.t("base.org.sign_out.completed_description"), inertia_props.fetch("description")
    assert_nil session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]

    get(
      base_org_sign_out_completion_url(host: @host, ri: "jp", state: query.fetch("state")),
      headers: host_headers(@host),
    )

    assert_response :not_found
  ensure
    Base::Org::SignOutsController.allow_forgery_protection = original
  end
end
