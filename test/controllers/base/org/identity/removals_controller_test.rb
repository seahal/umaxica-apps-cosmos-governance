# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    2.times do |index|
      OperatorPasskey.create!(
        staff: @operator, webauthn_id: "removal-fixture-#{index}", external_id: SecureRandom.uuid,
        public_key: "removal-fixture-key-#{index}", description: "Removal fixture",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    @secret = OperatorSecretCredential.create!(
      staff: @operator, name: "Retained secret", password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    @headers = as_staff_headers(@operator, host: @host)
  end

  test "registered passkeys do not replace unavailable Access authority for secret removal" do
    assert_equal [:passkey], AuthenticationCredentialInventory.call(@operator, excluding: @secret).sign_in_methods
    original = @secret.reload.attributes

    post base_org_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal original, @secret.reload.attributes
  end

  test "direct credential deletion also refuses without removing or revoking the secret" do
    original = @secret.reload.attributes

    delete base_org_identity_secret_url(@secret.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :service_unavailable
    assert_nil response.location
    assert_equal original, @secret.reload.attributes
  end

  test "unavailable removal does not disclose whether a foreign credential exists" do
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    foreign = OperatorSecretCredential.create!(
      staff: other, name: "Foreign secret", password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    original = foreign.reload.attributes

    [@secret.public_id, foreign.public_id, "nonexistent"].each do |reference|
      post base_org_identity_secret_removal_url(reference, ri: "jp", host: @host), headers: @headers

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
      assert_not_includes response.body, "Foreign secret"
    end
    assert_equal original, foreign.reload.attributes
  end

  test "standby external proof cannot update or remove a credential while authority is unavailable" do
    access = jwt_access_token_for(
      @operator, host: @host, resource_type: "operator", authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser_cookies = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie"))
    browser_cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookie_header = browser_cookies.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; ")
    headers = @headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    original = @secret.reload.attributes

    patch base_org_identity_secret_url(@secret.public_id, ri: "jp", host: @host),
          params: { staff_secret_credential: { name: "Refused" } }, headers: headers

    assert_response :service_unavailable
    assert_equal original, @secret.reload.attributes
    post base_org_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    assert_equal original, @secret.reload.attributes
  end
end
