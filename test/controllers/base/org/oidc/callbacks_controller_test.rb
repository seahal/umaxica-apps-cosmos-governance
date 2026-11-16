# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOrgOidcCallbackTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  FixedJwksClient =
    Data.define(:key) do
      def lookup(_kid) = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    end

  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  BASE_ORG_HOST = HOSTS.base_staff.host
  CLIENT_ID = RpCellBinding.fetch("rp_base_org").client_id
  VISA_ORIGIN = Oidc::AcmeServiceOrigin.from_configured_host(HOSTS.visa_staff.host, default_scheme: "https")
  PENDING_FLOWS_KEY = OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY

  test "a front-channel Base Org ID Token creates an operator RP session without Access or Refresh cookies" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host!(BASE_ORG_HOST)
    https!
    get("/sign", params: { ri: "jp" })

    assert_response :success
    csrf_token = css_select("input[name='authenticity_token']").sole["value"]
    authorization_url = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"
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
          "/sign", params: { ri: "jp", authenticity_token: csrf_token }, headers: {
            "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end

    assert_response :see_other
    query = Rack::Utils.parse_nested_query(URI.parse(authorization_url).query.to_s)

    assert_equal "id_token", query.fetch("response_type")
    assert_equal CLIENT_ID, query.fetch("client_id")
    assert_not query.key?("code_challenge")
    assert_not query.key?("code_challenge_method")
    state = OidcStateJwt.verify(client_id: CLIENT_ID, token: query.fetch("state"))

    assert_predicate state, :valid?
    flow = session.fetch(PENDING_FLOWS_KEY).fetch(state.jti)

    assert_not flow.key?("code_verifier")

    signing_key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    token = JWT.encode(
      {
        "iss" => VISA_ORIGIN.origin,
        "aud" => [CLIENT_ID],
        "exp" => now + 120,
        "iat" => now,
        "sub" => "base-org-callback-subject",
        "nonce" => flow.fetch("nonce"),
        "jti" => SecureRandom.uuid,
        "sid" => "base-org-callback-sid",
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => now - 60,
      }, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => "base-org-callback-test" },
    )
    events = []
    OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { FixedJwksClient.new(signing_key.public_key) }) do
      Rails.logger.stub(:info, ->(message = nil, &block) { events << (message || block&.call).to_s }) do
        get("/oidc/callback", params: { state: query.fetch("state"), iss: VISA_ORIGIN.origin, id_token: token })
      end
    end

    assert_response :see_other
    assert_equal "/dashboard", URI.parse(response.location).path
    assert_not_includes response.location, token
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_not_includes events.join, token
    assert_nil session[PENDING_FLOWS_KEY]
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :present?
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    RpBaseOrgRecord.connected_to(role: :writing) do
      assert_equal 1, RpBaseOrgSession.count
      binding = RpBaseOrgOpSessionBinding.includes(:identity_binding).find_by!(sid: "base-org-callback-sid")

      assert_equal VISA_ORIGIN.origin, binding.issuer
      assert_equal "org", binding.realm
      assert_equal CLIENT_ID, binding.client_id
      assert_equal "base-org-callback-subject", binding.identity_binding.subject
      assert_equal 1, RpBaseOrgConsumedIdTokenJti.count
      assert_equal ["pwd"], RpBaseOrgSessionAuthenticationEvidence.first!.amr
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
