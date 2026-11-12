# frozen_string_literal: true

require "test_helper"

class ClientSecretNameCommittedHttpTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_secret_credentials

  test "fresh signed Access step-up claims cannot rename a Secret without the Access proof query" do
    actor = clients(:one)
    credential = client_secret_credentials(:one)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(actor, host:)
    cookie_values = headers.fetch("Cookie").split("; ").to_h { |pair| pair.split("=", 2) }
    payload, = JWT.decode(
      Rack::Utils.unescape(cookie_values.fetch(OidcRpBrowserCredentialContract::ACCESS_COOKIE)),
      nil, false,
    )
    payload.merge!("acr" => StepUpEvidenceResolver::STEP_UP_ACR, "amr" => ["passkey"], "auth_time" => Time.current.to_i)
    access = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE,
               issuer_id: "surface:BASE_APP",
    )
    cookie_values[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = Rack::Utils.escape(access)
    headers["Cookie"] = cookie_values.map { |name, value| "#{name}=#{value}" }.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    headers["Authorization"] = "Bearer #{access}"
    original = credential.attributes

    assert_no_difference "ClientSecretAuditOutbox.count" do
      patch base_app_secret_url(credential.public_id, ri: "jp", host:), params: { name: "Unavailable rename" },
                                                                        headers: headers
    end

    assert_response :service_unavailable
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal original, credential.reload.attributes
    assert_nil response.location
  end
end
