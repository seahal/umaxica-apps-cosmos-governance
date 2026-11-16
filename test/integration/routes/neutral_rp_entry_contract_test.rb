# frozen_string_literal: true

require "test_helper"

class NeutralRpEntryContractTest < ActionDispatch::IntegrationTest
  VisaHost = Data.define(:host)
  VisaHosts = Data.define(:base_service, :base_corporate, :base_staff, :tech_staff, :visa_service)

  class FixedJwksClient
    def initialize(key)
      @key = key
    end

    def lookup(_kid)
      OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil)
    end
  end

  test "Base App has only the neutral entry, interruption and protocol callback routes" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    routes =
      Rails.application.routes.routes.filter_map do |route|
        next unless route.defaults[:controller].to_s.start_with?("base/app/")
        next unless route.path.spec.to_s.match?(%r{\A/(?:sign(?:/interruption)?|oidc/callback)(?:\(.:format\))?\z})

        [route.verb, route.path.spec.to_s, route.defaults[:controller], route.defaults[:action]]
      end

    assert_includes routes, ["GET", "/sign(.:format)", "base/app/sign/entries", "show"]
    assert_includes routes, ["POST", "/sign(.:format)", "base/app/sign/entries", "create"]
    assert_includes routes, ["GET", "/sign/interruption(.:format)", "base/app/sign/interruptions", "show"]
    assert_includes routes, ["GET", "/oidc/callback(.:format)", "base/app/oidc/callbacks", "show"]
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/verification/oidc/callback", method: :get)
    end
  end

  test "GET sign renders a passive page without creating a pending flow" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_no_difference -> { RpBaseAppPrincipal.count } do
      get "/sign", params: { ri: "jp" }
    end

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    form = css_select("form").sole

    assert_equal "post", form["method"]
    assert_equal "/sign", URI.parse(form["action"]).path
    assert_nil session["oidc_pending_flows"]
  end

  test "POST sign requires the Rails CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    post("/sign", params: { target_link_uri: "/dashboard" })

    assert_response :unprocessable_content
    assert_nil session["oidc_pending_flows"]
  ensure
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "POST sign creates one PS256 state-indexed front-channel ID Token flow through Jump" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    https!
    get("/sign", params: { ri: "jp", target_link_uri: "/dashboard" })

    assert_response :success
    csrf_token = css_select("input[name='authenticity_token']").sole["value"]
    authorization_url = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"
    with_visa_service_config do
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
            "/sign", params: {
              ri: "jp", target_link_uri: "/dashboard", authenticity_token: csrf_token,
            }, headers: {
              "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end
    end

    assert_response :see_other
    assert_equal jump_destination, response.location
    uri = URI.parse(authorization_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal "visa.umaxica.app", uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal %w(client_id nonce redirect_uri response_type ri scope state), query.keys.sort
    assert_equal "id_token", query.fetch("response_type")
    assert_equal "base-app-ww", query.fetch("client_id")
    assert_equal "openid profile", query.fetch("scope")
    assert_equal "jp", query.fetch("ri")
    assert_equal "/oidc/callback", URI.parse(query.fetch("redirect_uri")).path
    assert_predicate query.fetch("nonce"), :present?
    state = OidcStateJwt.verify(client_id: "base-app-ww", token: query.fetch("state"))

    assert_predicate state, :valid?
    assert_equal "/dashboard", state.target_link_uri
    pending = session.fetch("oidc_pending_flows").fetch(state.jti)

    assert_equal query.fetch("nonce"), pending.fetch("nonce")
    assert_not pending.key?("code_verifier")
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "a second sign POST replaces the pending flow and the first callback is refused" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    get("/sign", params: { ri: "jp" })
    csrf_token = css_select("input[name='authenticity_token']").sole["value"]
    authorization_urls = []
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"

    with_visa_service_config do
      JumpRtIssuer.stub(
        :call, ->(namespace:, url:, dst:, preserve_query_keys:) {
                 authorization_urls << url
                 "opaque-test-ticket"
               },
      ) do
        RedirectsJumpGatewayUrl.stub(
          :call, ->(_ticket) {
            RedirectsTargetResult.ok(kind: :external, source: :test, value: jump_destination)
          },
        ) do
          2.times do
            post(
              "/sign", params: { ri: "jp", authenticity_token: csrf_token }, headers: {
                "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
              },
            )

            assert_response :see_other
          end
        end
      end
    end

    first_state_token = Rack::Utils.parse_nested_query(URI.parse(authorization_urls.first).query).fetch("state")
    second_state_token = Rack::Utils.parse_nested_query(URI.parse(authorization_urls.second).query).fetch("state")
    first_state = OidcStateJwt.verify(client_id: "base-app-ww", token: first_state_token)
    second_state = OidcStateJwt.verify(client_id: "base-app-ww", token: second_state_token)

    assert_not_equal first_state.jti, second_state.jti
    assert_equal [second_state.jti], session.fetch("oidc_pending_flows").keys

    get("/oidc/callback", params: { state: first_state_token })

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_nil session["oidc_pending_flows"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "POST sign fails closed when the Visa host-family contract is absent" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    get("/sign", params: { ri: "jp" })

    assert_response :success
    with_visa_service_config(visa_service: nil) do
      post("/sign", params: { ri: "jp" })
    end

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil session["oidc_pending_flows"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "an authenticated Base App browser is refused both the entry page and a new flow" do
    [ClientStatus, ClientMfaStatus, ClientVisibility].each(&:ensure_defaults!)
    ClientSecurityMode.find_or_create_by!(id: ClientSecurityMode::NORMAL)
    actor = Client.create!(security_mode_id: ClientSecurityMode::NORMAL, status_id: ClientStatus::ACTIVE)
    cell = RpCellBinding.fetch("rp_base_app")
    issuer = "https://visa.umaxica.app"
    subject = OidcSubject.for(actor, resource_type: "client")
    sid = SecureRandom.uuid
    rp_session = seed_rp_cell_session(cell:, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now)
    key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    access_token = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "exp" => now + 300,
        "nbf" => now - 1,
        "iat" => now,
        "sub" => subject,
        "sid" => sid,
        "client_id" => cell.client_id,
        "jti" => SecureRandom.uuid,
        "scope" => "openid profile",
        "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
      }, key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "base-app-entry-test", "typ" => "at+jwt" },
    )
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_session.public_id
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false

    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_jwks_uri) { FixedJwksClient.new(key.public_key) }) do
        get("/sign", params: { ri: "jp" })

        assert_response :forbidden
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_equal "no-store", response.headers["Cache-Control"]

        post("/sign", params: { ri: "jp" })

        assert_response :forbidden
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_nil session["oidc_pending_flows"]
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "an OIDC callback without a state ends on the generic interruption page" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get "/oidc/callback"

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "callbacks with tampered, expired, or foreign-client state end on the generic interruption page" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    valid_state, = OidcStateJwt.issue(client_id: "base-app-ww", target_link_uri: nil)
    expired_state, = OidcStateJwt.issue(
      client_id: "base-app-ww", target_link_uri: nil, now: OidcStateJwt::TTL.ago - 1.second,
    )
    foreign_state, = OidcStateJwt.issue(client_id: "base-org-ww", target_link_uri: nil)
    tampered_state = "#{valid_state[0...-1]}x"

    [tampered_state, expired_state, foreign_state].each do |state|
      get "/oidc/callback", params: { state: }

      assert_response :see_other
      assert_equal "/sign/interruption", URI.parse(response.location).path
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "a callback with a wrong response issuer is refused before ID Token lookup" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get "/sign", params: { ri: "jp" }

    assert_response :success
    state, jti = OidcStateJwt.issue(client_id: "base-app-ww", target_link_uri: nil)
    session["oidc_pending_flows"] = {
      jti => { "nonce" => "rp-nonce",
               "created_at" => Time.current.to_i, },
    }

    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { flunk("wrong issuer must stop before ID Token lookup") }) do
        get "/oidc/callback", params: {
          state:, iss: "https://attacker.example", id_token: "unverified-front-channel-token",
        }
      end
    end

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_nil session["oidc_pending_flows"]
  end

  test "the neutral entry and interruption pages do not render application header navigation" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get "/sign", params: { ri: "jp" }

    assert_response :success
    assert_select "nav", count: 0

    get "/sign/interruption", params: { ri: "jp" }

    assert_response :success
    assert_select "nav", count: 0
  end

  private

  def with_visa_service_config(visa_service: VisaHost.new("visa.umaxica.app"))
    current_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    hosts = VisaHosts.new(
      base_service: current_hosts.base_service,
      base_corporate: current_hosts.base_corporate,
      base_staff: current_hosts.base_staff,
      tech_staff: current_hosts.tech_staff,
      visa_service:,
    )
    boot_config = Rails.configuration.x.boot_config.merge(hosts:)
    Rails.configuration.x.stub(:boot_config, boot_config) { yield }
  end
end
