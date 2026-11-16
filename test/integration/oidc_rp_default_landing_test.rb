# frozen_string_literal: true

require "test_helper"

class OidcRpDefaultLandingTest < ActionDispatch::IntegrationTest
  VISA_ISSUER = "https://visa.umaxica.app"
  CLIENT_ID = "base-app-ww"

  VisaHost = Data.define(:host)
  VisaHosts = Data.define(:base_service, :base_corporate, :base_staff, :tech_staff, :visa_service)

  FixedJwksClient =
    Data.define(:key, :kid) do
      def lookup(candidate_kid)
        return OidcOpJwksClient::Lookup.new(
          status: :invalid, key: nil,
          reason: "unknown_kid",
        ) unless candidate_kid == kid

        OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      end
    end

  test "a verified front-channel Base App callback without a path target lands on the dashboard" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    authorization_query = start_browser_flow
    state = authorization_query.fetch("state")
    pending_flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY)
      .fetch(OidcStateJwt.verify(client_id: CLIENT_ID, token: state).jti)
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-landing-test"
    now = Time.current.to_i
    id_token = JWT.encode(
      {
        "iss" => VISA_ISSUER,
        "aud" => [CLIENT_ID],
        "exp" => now + 120,
        "iat" => now,
        "sub" => "landing-test-subject",
        "nonce" => pending_flow.fetch("nonce"),
        "jti" => SecureRandom.uuid,
        "sid" => "landing-test-sid",
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => now - 60,
      }, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid },
    )

    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { FixedJwksClient.new(signing_key.public_key, kid) }) do
        get "/oidc/callback", params: { state:, iss: VISA_ISSUER, id_token: }
      end
    end

    assert_response :see_other
    assert_equal "/dashboard", URI.parse(response.location).path
    assert_not_includes response.location, id_token
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    RpBaseAppRecord.connected_to(role: :writing) do
      assert_equal 1, RpBaseAppSession.count
    end
  end

  private

  def start_browser_flow
    get("/sign", params: { ri: "jp" })

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
            "/sign", params: { ri: "jp", authenticity_token: csrf_token }, headers: {
              "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end
    end

    assert_response :see_other
    assert_equal jump_destination, response.location
    Rack::Utils.parse_nested_query(URI.parse(authorization_url).query.to_s)
  end

  def with_visa_service_config
    current_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    hosts = VisaHosts.new(
      base_service: current_hosts.base_service,
      base_corporate: current_hosts.base_corporate,
      base_staff: current_hosts.base_staff,
      tech_staff: current_hosts.tech_staff,
      visa_service: VisaHost.new("visa.umaxica.app"),
    )
    Rails.configuration.x.stub(:boot_config, Rails.configuration.x.boot_config.merge(hosts:)) { yield }
  end
end
