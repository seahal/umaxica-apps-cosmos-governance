# frozen_string_literal: true

require "test_helper"

class StaffLifecycleBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :operators

  test "ORG withdrawal stays informational for an authenticated local RP session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    2.times do
      OperatorPasskey.create!(
        staff: actor, external_id: SecureRandom.alphanumeric(21), webauthn_id: SecureRandom.alphanumeric(21),
        public_key: "staff-info-public-key", sign_count: 0, description: "Staff information", status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(actor, host:)

    cookie_values = headers.fetch("Cookie").split("; ").to_h { |pair| pair.split("=", 2) }
    payload, = JWT.decode(
      Rack::Utils.unescape(cookie_values.fetch(OidcRpBrowserCredentialContract::ACCESS_COOKIE)),
      nil, false,
    )
    payload.merge!("acr" => StepUpEvidenceResolver::STEP_UP_ACR, "amr" => ["passkey"], "auth_time" => Time.current.to_i)
    access = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE, issuer_id: "surface:BASE_ORG",
    )
    cookie_values[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = Rack::Utils.escape(access)
    headers["Cookie"] = cookie_values.map { |name, value| "#{name}=#{value}" }.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    headers["Authorization"] = "Bearer #{access}"

    get base_org_identity_withdrawal_url(ri: "jp", host:), headers: headers

    assert_response :success
    assert_nil actor.reload.deactivated_at
    assert_equal base_org_identity_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
  end

  test "ORG has no destructive self-service withdrawal verbs" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    headers = as_staff_headers(actor, host:)

    patch base_org_identity_withdrawal_url(ri: "jp", host:), params: { ack_deactivate_today: "1" }, headers: headers

    assert_response :not_found

    delete base_org_identity_withdrawal_url(ri: "jp", host:), headers: headers

    assert_response :not_found
    assert_nil actor.reload.deactivated_at
  end
end
