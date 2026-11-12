# frozen_string_literal: true

require "test_helper"

class BaseRpFixtureCredentialsTest < ActionDispatch::IntegrationTest
  [
    [:app, Client, "base-app-ww", "PUBLIC_BASE_SERVICE_URL", RpBaseAppSession],
    [:org, Operator, "base-org-ww", "PUBLIC_BASE_STAFF_URL", RpBaseOrgSession],
  ].each do |surface, actor_model, client_id, host_key, session_model|
    test "#{surface} signed external fixture authenticates the real local RP session and canonical actor" do
      actor = actor_model.first!
      host = ENV.fetch(host_key)
      headers =
        if surface == :app
          as_user_headers(actor, host:, select_available_app_persona: false)
        else
          as_staff_headers(actor, host:)
        end
      access_token = headers.fetch("Authorization").delete_prefix("Bearer ")
      cookies = Rack::Utils.parse_query(headers.fetch("Cookie").split("; ").join("&"))
      local_session_id = cookies.fetch(OidcRpBrowserCredentialContract::SESSION_COOKIE)
      cell = RpCellBinding.for_client(client_id)
      issuer = OidcIssuer.for_resource_type((cell.realm == "app") ? "client" : "operator")
      jwks_client = OidcOpJwksClient.for_resource_type((cell.realm == "app") ? "client" : "operator")
      result = RpRequestAuthenticator.call(cell:, access_token:, local_session_id:, issuer:, jwks_client:)

      assert_equal :authenticated, result.status
      assert_instance_of session_model, result.session
      assert_equal local_session_id, result.session.public_id
      assert_equal OidcSubject.for(actor, resource_type: (cell.realm == "app") ? "client" : "operator"),
                   result.payload.fetch("sub")
      assert_equal [client_id], result.payload.fetch("aud")
      assert_not headers.key?("X-TEST-CURRENT-USER")
      assert_not headers.key?("X-TEST-CURRENT-STAFF")
      assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      state = BrowserRpAuthentication::AccessState.new(
        status: :valid, resource: result.principal, rp_session: result.session,
        payload: result.payload, security_context: nil,
      )

      assert_equal actor, BaseZenithIdentityResolver.call(access_state: state, surface:)
      assert_equal :invalid,
                   RpRequestAuthenticator.call(
                     cell:, access_token:, local_session_id: SecureRandom.uuid, issuer:, jwks_client:,
                   ).status
    end
  end

  test "an Authority host cannot obtain fabricated local RP fixture credentials" do
    assert_raises(AccessOpDataUnavailableError) do
      as_user_headers(Client.first!, host: "sign.example.test", select_available_app_persona: false)
    end
  end
end
