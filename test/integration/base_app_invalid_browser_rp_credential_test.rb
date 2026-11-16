# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAppInvalidBrowserRpCredentialTest < ActionDispatch::IntegrationTest
  test "JSON Home refuses a malformed RP credential and clears its browser cookies" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    access_cookie = OidcRpBrowserCredentialContract::ACCESS_COOKIE
    session_cookie = OidcRpBrowserCredentialContract::SESSION_COOKIE
    cookies[access_cookie] = "malformed-access-credential"
    cookies[session_cookie] = "stale-local-session"

    get base_app_root_url(ri: "jp", format: :json)

    assert_response :unauthorized
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("errors.messages.login_required"), response.body
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.location

    set_cookie_headers = Array(response.headers["Set-Cookie"]).join("\n")
    [access_cookie, session_cookie].each do |cookie_name|
      deletion = set_cookie_headers.lines.find { |line| line.start_with?("#{cookie_name}=") }

      assert_predicate deletion, :present?, "expected #{cookie_name} to be detached"
      assert_match(/(?:max-age=0|expires=Thu, 01 Jan 1970)/i, deletion)
    end
  end
end
