# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/rp_cell_session_helper"

class Base::Org::Identity::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
  end

  [nil, "1990-01-02"].each do |birthdate|
    test "missing fresh OP evidence protects #{birthdate ? "stored" : "unset"} birthdate" do
      @operator.update!(birthdate: birthdate)
      headers = as_staff_headers(@operator, host: @host).merge(
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Accept" => "text/html",
      )
      get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: headers

      assert_response :unauthorized
      assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
      assert_not_includes response.body, "1990-01-02"
      birthdate.nil? ? assert_nil(@operator.reload.birthdate) : assert_equal(birthdate, @operator.reload.birthdate)
    end
  end

  test "standby external proof cannot reveal a step-up protected birthdate" do
    @operator.update!(birthdate: "1990-01-02")
    headers = as_staff_headers(@operator, host: @host)
    access = jwt_access_token_for(
      @operator, host: @host, resource_type: "operator", authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    browser_cookies = Rack::Utils.parse_cookies_header(headers.fetch("Cookie"))
    browser_cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookie_header = browser_cookies.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)

    assert_no_difference -> { RpBaseOrgStepUpState.count } do
      get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: headers
    end
    assert_response :unauthorized
    assert_not_includes response.body, "1990-01-02"
    assert_equal "1990-01-02", @operator.reload.birthdate
  end

  test "missing local RP step-up evidence renders a challenge for a browser document navigation" do
    host! @host
    https!
    cell = RpCellBinding.for_client("base-org-ww")
    client = OidcClientRegistry.find!(cell.client_id)
    issuer = rp_test_issuer_for(client)
    subject = OidcSubject.for(@operator, resource_type: "operator")
    sid = SecureRandom.uuid
    enrollment = seed_rp_cell_session(
      cell:, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now,
    )

    key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    access_token = JWT.encode(
      { "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => cell.client_id,
        AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY, },
      key, "PS256", { "kid" => "birthdate-step-up-test", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: rp_test_jwks_uri_for(client),
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "birthdate-step-up-test")] } },
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.public_id

    RuntimeRole.stub(:current, "rp-base-org-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        OidcOpJwksClient.stub(:for_jwks_uri, jwks) do
          get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: {
            "Host" => @host,
            "Accept" => "text/html",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          }
        end
      end
    end

    assert_response :unauthorized
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_select "h1", text: I18n.t("auth.step_up.challenge.title")
    assert_select "a", text: I18n.t("actions.continue")
  end

  test "stored birthdate remains unavailable without locally supported step-up evidence" do
    @operator.update!(birthdate: "1990-01-02")
    headers = as_staff_headers(@operator, host: @host)

    RuntimeRole.stub(:current, "rp-base-org-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: headers
      end
    end

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_not_includes response.body, "1990-01-02"
  end

  private
end
