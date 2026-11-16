# frozen_string_literal: true

require "test_helper"

class BaseRpFixtureCredentialsTest < ActionDispatch::IntegrationTest
  [
    [:app, Client, "base-app-ww", "PUBLIC_BASE_SERVICE_URL", RpBaseAppSession],
    [:org, Operator, "base-org-ww", "PUBLIC_BASE_STAFF_URL", RpBaseOrgSession],
  ].each do |surface, actor_model, client_id, host_key, session_model|
    test "#{surface} local RP session authenticates the canonical actor without an Access credential" do
      actor = actor_model.first!
      host = ENV.fetch(host_key)
      headers =
        if surface == :app
          as_user_headers(actor, host:, select_available_app_persona: false)
        else
          as_staff_headers(actor, host:)
        end
      cookies = Rack::Utils.parse_query(headers.fetch("Cookie").split("; ").join("&"))
      local_session_id = cookies.fetch(OidcRpBrowserCredentialContract::SESSION_COOKIE)
      cell = RpCellBinding.for_client(client_id)
      client = OidcClientRegistry.find!(client_id)
      raise ArgumentError, "unsupported Base RP fixture surface: #{surface.inspect}" unless
        %i(app org).include?(surface)

      issuer = rp_test_issuer_for(client)
      result = BaseRpSessionAuthenticator.call(cell:, local_session_id:, issuer:)

      assert_equal :authenticated, result.status
      assert_instance_of session_model, result.session
      assert_equal local_session_id, result.session.public_id
      assert_equal actor, BaseZenithIdentityResolver.call(
        access_state: BrowserRpAuthentication::AccessState.new(
          status: :valid, resource: result.principal, rp_session: result.session, payload: result.payload,
          security_context: nil,
        ),
        surface:,
      )
      assert_equal [client_id], result.payload.fetch("aud")
      assert_not headers.key?("X-TEST-CURRENT-USER")
      assert_not headers.key?("X-TEST-CURRENT-STAFF")
      assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      assert_equal :invalid, BaseRpSessionAuthenticator.call(
        cell:, local_session_id: SecureRandom.uuid, issuer:,
      ).status
    end
  end

  test "an Authority host cannot obtain fabricated local RP fixture credentials" do
    assert_raises(AccessOpDataUnavailableError) do
      as_user_headers(Client.first!, host: "sign.example.test", select_available_app_persona: false)
    end
  end
end
