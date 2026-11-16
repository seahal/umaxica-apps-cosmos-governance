# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseRpRealmIsolationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  APP_CLIENT_ID = RpCellBinding.fetch("rp_base_app").client_id
  ORG_CLIENT_ID = RpCellBinding.fetch("rp_base_org").client_id
  APP_HOST = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
  ORG_HOST = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
  APP_VISA_ISSUER = "https://visa.umaxica.app"
  ORG_VISA_ISSUER = "https://visa.umaxica.org"
  PENDING_FLOWS_KEY = OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY

  test "each Base callback rejects state signed for the other RP client" do
    [
      { host: ORG_HOST, issuer: ORG_VISA_ISSUER, state_client_id: APP_CLIENT_ID },
      { host: APP_HOST, issuer: APP_VISA_ISSUER, state_client_id: ORG_CLIENT_ID },
    ].each do |scenario|
      state, = OidcStateJwt.issue(client_id: scenario.fetch(:state_client_id), target_link_uri: nil)
      host! scenario.fetch(:host)

      get "/oidc/callback", params: { state:, iss: scenario.fetch(:issuer), code: "one-time-code" }

      assert_response :see_other
      assert_equal "/sign/interruption", URI.parse(response.location).request_uri
    end
  end

  test "each Base callback rejects the other realm's Visa issuer before reading the ID Token" do
    [
      {
        host: APP_HOST,
        client_id: APP_CLIENT_ID,
        expected_issuer: APP_VISA_ISSUER,
        presented_issuer: ORG_VISA_ISSUER,
      },
      {
        host: ORG_HOST,
        client_id: ORG_CLIENT_ID,
        expected_issuer: ORG_VISA_ISSUER,
        presented_issuer: APP_VISA_ISSUER,
      },
    ].each do |scenario|
      host! scenario.fetch(:host)
      get "/sign", params: { ri: "jp" }

      assert_response :success
      state, jti = OidcStateJwt.issue(client_id: scenario.fetch(:client_id), target_link_uri: nil)
      session[PENDING_FLOWS_KEY] = {
        jti => {
          "created_at" => Time.current.to_i,
          "nonce" => "callback-realm-isolation",
        },
      }
      OidcOpJwksClient.stub(
        :for_jwks_uri, ->(_uri) { flunk("a mismatched issuer must stop before ID Token verification") },
      ) do
        get "/oidc/callback", params: {
          state:, iss: scenario.fetch(:presented_issuer), id_token: "unverified-front-channel-token",
        }
      end

      assert_response :see_other
      assert_equal "/sign/interruption", URI.parse(response.location).request_uri
      assert_nil session[PENDING_FLOWS_KEY]
      assert_not_equal scenario.fetch(:expected_issuer), scenario.fetch(:presented_issuer)
    end
  end

  test "a Base App RP cookie does not authenticate a browser on Base Org" do
    actor = Client.create!(
      security_mode_id: ClientSecurityMode::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    app_headers = as_user_headers(actor, host: APP_HOST, select_available_app_persona: false)
    host! ORG_HOST
    jwks_client = Object.new

    jwks_client.define_singleton_method(:lookup) do |_kid|
      flunk("an App-issued token must be rejected by issuer before Org key lookup")
    end

    as_rp_cell(ORG_CLIENT_ID) do
      OidcOpJwksClient.stub(:for_jwks_uri, ->(_uri) { jwks_client }) do
        get "/dashboard", params: { ri: "jp" }, headers: { "Cookie" => app_headers.fetch("Cookie") }
      end
    end

    assert_response :see_other
    assert_equal "/sign", URI.parse(response.location).path
    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)

    assert_equal "jp", query.fetch("ri")
    assert_equal "/dashboard", query.fetch("target_link_uri")
    assert_includes set_cookie_names, OidcRpBrowserCredentialContract::ACCESS_COOKIE
    assert_includes set_cookie_names, OidcRpBrowserCredentialContract::SESSION_COOKIE
  end
end
