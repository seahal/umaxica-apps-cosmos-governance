# frozen_string_literal: true

require "test_helper"

class Base::App::WelcomesControllerTest < ActionDispatch::IntegrationTest
  test "authenticated RP Welcome reads its selection without issuing another local session" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    headers = as_user_headers(client, host:)
    session_public_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    rp_session = RpBaseAppSession.find_by!(public_id: session_public_id)
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id)
    original_session = rp_session.attributes
    original_selection = selection.attributes
    session_count = RpBaseAppSession.count

    get base_app_welcome_url(ri: "jp", host:), headers: headers

    assert_response :success
    assert_includes response.body, base_app_dashboard_path(ri: "jp")
    assert_equal session_count, RpBaseAppSession.count
    assert_equal original_session, rp_session.reload.attributes
    assert_equal original_selection, selection.reload.attributes
  end
end
