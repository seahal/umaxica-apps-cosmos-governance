# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAppOidcCallbackRouteTest < ActionDispatch::IntegrationTest
  test "the Base App callback is routed to its own controller" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_routing(
      { method: :get, path: "https://#{host}/oidc/callback" },
      { controller: "base/app/oidc/callbacks", action: "show" },
    )
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/oidc/authorization", method: :get)
    end
  end
end

class BaseAppOidcCallbackTest < ActionDispatch::IntegrationTest
  VISA_ISSUER = "https://visa.umaxica.app"
  CLIENT_ID = "base-app-ww"
  OIDC_PENDING_FLOWS = OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY

  VisaHost = Data.define(:host)
  VisaHosts = Data.define(:base_service, :base_corporate, :base_staff, :visa_service, :visa_staff, :tech_staff)

  class FixedJwksClient
    attr_reader :lookups

    def initialize(key, kid)
      @key = key
      @kid = kid
      @lookups = []
    end

    def lookup(kid)
      lookups << kid
      return OidcOpJwksClient::Lookup.new(status: :invalid, key: nil, reason: "unknown_kid") unless kid == @kid

      OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil)
    end
  end

  test "the initiator uses front-channel ID Token without PKCE and callback commits a sid-bound session" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    authorization_query, start_events, authorization_url, jump_destination =
      start_browser_flow(target_link_uri: "/dashboard")
    state = authorization_query.fetch("state")
    state_result = OidcStateJwt.verify(client_id: CLIENT_ID, token: state)

    assert_predicate state_result, :valid?
    assert_equal "/dashboard", state_result.target_link_uri
    assert_equal "id_token", authorization_query.fetch("response_type")
    assert_equal CLIENT_ID, authorization_query.fetch("client_id")
    assert_equal "openid profile", authorization_query.fetch("scope")
    assert_not authorization_query.key?("code_challenge")
    assert_not authorization_query.key?("code_challenge_method")
    pending_flow = session.fetch(OIDC_PENDING_FLOWS).fetch(state_result.jti)
    nonce = pending_flow.fetch("nonce")

    assert_not pending_flow.key?("code_verifier")
    session_cookie_key = Rails.application.config.session_options.fetch(:key)
    previous_rails_session_id = request.cookie_jar.signed_or_encrypted[session_cookie_key].fetch("session_id")
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-callback-test"
    id_token = issue_id_token(signing_key, kid:, nonce:)
    jwks_client = FixedJwksClient.new(signing_key.public_key, kid)
    callback_url = "#{request.base_url}/oidc/callback?#{Rack::Utils.build_query(
      state:, iss: VISA_ISSUER, id_token:,
    )}"
    callback_events = start_events.dup

    assert_operator utf16_code_units(callback_url), :<=, JumpRtIssuer::MAX_URL_LENGTH

    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { jwks_client }) do
        Rails.logger.stub(
          :info, ->(message = nil, &block) {
                   callback_events << (message || block&.call).to_s
                 },
        ) do
          get "/oidc/callback", params: { state:, iss: VISA_ISSUER, id_token: }
        end
      end
    end

    assert_response :see_other, callback_events.join("\n")
    assert_equal "/dashboard", URI.parse(response.location).path
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_not_includes response.location, id_token
    assert_nil session[OIDC_PENDING_FLOWS]
    assert session[:inertia_clear_history]
    new_rails_session_id = request.cookie_jar.signed_or_encrypted[session_cookie_key].fetch("session_id")

    assert_not_equal previous_rails_session_id, new_rails_session_id
    [state, nonce, id_token, authorization_url, jump_destination].each do |sensitive_value|
      assert_not_includes callback_events.join, sensitive_value
    end
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :present?
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    RpBaseAppRecord.connected_to(role: :writing) do
      assert_equal 1, RpBaseAppSession.count
      binding = RpBaseAppOpSessionBinding.includes(:identity_binding).first!

      assert_equal VISA_ISSUER, binding.issuer
      assert_equal "callback-sid", binding.sid
      assert_equal "callback-subject", binding.identity_binding.subject
      evidence = RpBaseAppSessionAuthenticationEvidence.first!

      assert_equal "urn:umaxica:base:normal", evidence.acr
      assert_equal ["pwd"], evidence.amr
      assert_equal 1, RpBaseAppConsumedIdTokenJti.count
    end

    logout_token = JWT.encode(
      {
        "iss" => VISA_ISSUER,
        "aud" => [CLIENT_ID],
        "iat" => Time.current.to_i,
        "exp" => Time.current.to_i + 120,
        "jti" => SecureRandom.uuid,
        "sid" => "callback-sid",
        "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
      }, signing_key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid, "typ" => "logout+jwt" },
    )
    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { FixedJwksClient.new(signing_key.public_key, kid) }) do
        post "/oidc/closures", params: { logout_token: }, headers: {
          "HTTP_COOKIE" => nil, "HTTP_USER_AGENT" => nil,
        }
      end
    end

    assert_response :ok
    RpBaseAppRecord.connected_to(role: :writing) do
      assert_predicate RpBaseAppSession.first!.reload.revoked_at, :present?
    end
  end

  test "an oversized front-channel callback URL is rejected before ID Token verification" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    authorization_query, = start_browser_flow(target_link_uri: nil)
    state = authorization_query.fetch("state")
    signing_key = OpenSSL::PKey::RSA.generate(3072)
    kid = "base-app-oversized-callback-test"
    token = issue_id_token(signing_key, kid:, nonce: authorization_nonce(state), amr: ["pwd", "x" * 1_600])
    jwks_client = FixedJwksClient.new(signing_key.public_key, kid)

    with_visa_service_config do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { jwks_client }) do
        get "/oidc/callback", params: { state:, iss: VISA_ISSUER, id_token: token }
      end
    end

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_empty jwks_client.lookups
    assert_equal 0, RpBaseAppConsumedIdTokenJti.count
  end

  test "front-channel callback URLs immediately below and at the Jump limit pass while the next unit is refused" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    signing_key = OpenSSL::PKey::RSA.generate(3072)

    [[2_047, true], [2_048, true], [2_049, false]].each do |target_length, accepted|
      authorization_query, = start_browser_flow(target_link_uri: nil)
      state = authorization_query.fetch("state")
      kid = "base-app-url-boundary-#{target_length}"
      token = issue_id_token(
        signing_key, kid:, nonce: authorization_nonce(state), subject: "size-#{target_length}",
                     sid: "size-#{target_length}",
      )
      callback_params = { state:, iss: VISA_ISSUER, id_token: token }
      callback_url = "#{request.base_url}/oidc/callback?#{Rack::Utils.build_query(callback_params)}"
      padding_length = target_length - utf16_code_units(callback_url) - "&padding=".length

      assert_operator padding_length, :>=, 0, "the generated signed callback must fit the tested bound"

      callback_params[:padding] = "x" * padding_length
      callback_url = "#{request.base_url}/oidc/callback?#{Rack::Utils.build_query(callback_params)}"

      assert_equal target_length, utf16_code_units(callback_url)
      jwks_client = FixedJwksClient.new(signing_key.public_key, kid)
      with_visa_service_config do
        OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { jwks_client }) do
          get "/oidc/callback", params: callback_params
        end
      end

      assert_response :see_other
      expected_path = accepted ? "/dashboard" : "/sign/interruption"

      assert_equal expected_path, URI.parse(response.location).path
      assert_equal accepted, jwks_client.lookups.any?
      cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
    end
  end

  test "state is checked before a front-channel token and mixed code or token responses are refused" do
    {
      code: "unexpected-code",
      access_token: "unexpected-access-token",
      refresh_token: "unexpected-refresh-token",
    }.each do |mixed_parameter, value|
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      https!
      authorization_query, = start_browser_flow(target_link_uri: nil)
      signing_key = OpenSSL::PKey::RSA.generate(3072)
      token = issue_id_token(signing_key, kid: "base-app-mixed-test", nonce: "unused")

      get "/oidc/callback", params: {
        :state => authorization_query.fetch("state"),
        :iss => VISA_ISSUER,
        :id_token => token,
        mixed_parameter => value,
      }

      assert_response :see_other
      assert_equal "/sign/interruption", URI.parse(response.location).path
      assert_not_includes response.location, token
      assert_equal 0, RpBaseAppConsumedIdTokenJti.count
    end
  end

  test "a missing or tampered state is rejected before the ID Token key is read" do
    [
      ["missing", ->(_state) { }],
      ["tampered", ->(state) { "x#{state[1..]}" }],
    ].each do |label, state_transform|
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      https!
      authorization_query, = start_browser_flow(target_link_uri: nil)
      state = state_transform.call(authorization_query.fetch("state"))

      OidcOpJwksClient.stub(
        :for_jwks_uri, ->(_uri) { flunk("invalid state must stop before ID Token key lookup") },
      ) do
        get "/oidc/callback", params: { state:, iss: VISA_ISSUER, id_token: "unverified-token" }
      end

      assert_response :see_other, label
      assert_equal "/sign/interruption", URI.parse(response.location).path, label
      assert_equal 0, RpBaseAppConsumedIdTokenJti.count, label
    end
  end

  test "login_required returns to the ordinary sign entry without echoing the response" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    authorization_query, = start_browser_flow(target_link_uri: "/dashboard")

    get "/oidc/callback", params: {
      state: authorization_query.fetch("state"), iss: VISA_ISSUER, error: "login_required",
    }

    assert_response :see_other
    assert_equal "/sign", URI.parse(response.location).path
    assert_equal "/dashboard", Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
      .fetch("target_link_uri")
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end

  test "other authorization errors fail closed without echoing a token" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    authorization_query, = start_browser_flow(target_link_uri: nil)

    get "/oidc/callback", params: {
      state: authorization_query.fetch("state"),
      iss: VISA_ISSUER,
      error: "access_denied",
      error_description: "provider response must not be reflected",
    }

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_not_includes response.location, "provider response"
  end

  test "an expired RP session renews through prompt none and remains bound to its Visa sid" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    cell = RpCellBinding.fetch("rp_base_app")
    initial = RpCallbackCommitter.call(
      cell:, issuer: VISA_ISSUER, subject: "renewal-subject", sid: "renewal-sid",
      absolute_expires_at: 1.hour.from_now,
      id_token_jti_digest: Digest::SHA256.hexdigest("initial-renewal-jti"),
      id_token_expires_at: 2.minutes.from_now,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => Time.current.to_i - 60,
        "id_token_jti_digest" => Digest::SHA256.hexdigest("initial-renewal-jti"),
      },
    )

    assert_predicate initial, :success?

    initial.session.update!(absolute_expires_at: 1.second.ago)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = initial.session.public_id

    get "/dashboard", params: { ri: "jp" }

    assert_response :see_other
    assert_equal "/sign", URI.parse(response.location).path
    assert_equal "/dashboard", Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
      .fetch("target_link_uri")

    authorization_query, = start_browser_flow(target_link_uri: "/dashboard")

    assert_equal "none", authorization_query.fetch("prompt")
    pending_state = OidcStateJwt.verify(client_id: CLIENT_ID, token: authorization_query.fetch("state"))
    pending_flow = session.fetch(OIDC_PENDING_FLOWS).fetch(pending_state.jti)

    assert_equal initial.session.public_id, pending_flow.fetch("renewal_session_id")

    signing_key = OpenSSL::PKey::RSA.generate(3072)
    id_token = issue_id_token(
      signing_key, kid: "base-app-renewal-test", nonce: pending_flow.fetch("nonce"),
                   subject: "renewal-subject", sid: "renewal-sid",
    )
    with_visa_service_config do
      OidcOpJwksClient.stub(
        :for_jwks_uri, ->(_uri) { FixedJwksClient.new(signing_key.public_key, "base-app-renewal-test") },
      ) do
        get "/oidc/callback", params: {
          state: authorization_query.fetch("state"), iss: VISA_ISSUER, id_token:,
        }
      end
    end

    assert_response :see_other
    assert_equal "/dashboard", URI.parse(response.location).path
    assert_equal initial.session.id, initial.session.reload.id
    assert_operator initial.session.absolute_expires_at, :>, Time.current
    assert_equal "renewal-sid", initial.session.op_session_binding.sid
  end

  private

  def start_browser_flow(target_link_uri:)
    get("/sign", params: { ri: "jp" })

    assert_response :success
    csrf_token = css_select("input[name='authenticity_token']").sole["value"]
    authorization_url = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"
    start_events = []
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
          Rails.logger.stub(:info, ->(message = nil, &block) { start_events << (message || block&.call).to_s }) do
            post(
              "/sign", params: { ri: "jp", target_link_uri:, authenticity_token: csrf_token }, headers: {
                "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
              },
            )
          end
        end
      end
    end

    assert_response :see_other
    assert_equal jump_destination, response.location
    [Rack::Utils.parse_nested_query(URI.parse(authorization_url).query.to_s), start_events,
     authorization_url, jump_destination,]
  end

  def issue_id_token(key, kid:, nonce:, amr: ["pwd"], subject: "callback-subject", sid: "callback-sid")
    now = Time.current.to_i
    payload = {
      "iss" => VISA_ISSUER,
      "aud" => [CLIENT_ID],
      "exp" => now + 120,
      "iat" => now,
      "sub" => subject,
      "nonce" => nonce,
      "jti" => SecureRandom.uuid,
      "sid" => sid,
      "acr" => "urn:umaxica:base:normal",
      "amr" => amr,
      "auth_time" => now - 60,
    }
    JWT.encode(payload, key, JitSecurityJwtJwk::ALGORITHM, { "kid" => kid })
  end

  def authorization_nonce(state)
    state_result = OidcStateJwt.verify(client_id: CLIENT_ID, token: state)
    session.fetch(OIDC_PENDING_FLOWS).fetch(state_result.jti).fetch("nonce")
  end

  def utf16_code_units(value)
    value.encode(Encoding::UTF_16LE).bytesize / 2
  end

  def with_visa_service_config
    current_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    hosts = VisaHosts.new(
      base_service: current_hosts.base_service,
      base_corporate: current_hosts.base_corporate,
      base_staff: current_hosts.base_staff,
      tech_staff: current_hosts.tech_staff,
      visa_service: VisaHost.new("visa.umaxica.app"),
      visa_staff: current_hosts.visa_staff,
    )
    boot_config = Rails.configuration.x.boot_config.merge(hosts:)
    Rails.configuration.x.stub(:boot_config, boot_config) { yield }
  end
end
