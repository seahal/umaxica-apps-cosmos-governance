# frozen_string_literal: true

require "test_helper"

class Base::App::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
    )
    @headers = as_user_headers(principal, host: @host)
    session_id = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    @rp_session = RpBaseAppSession.find_by!(public_id: session_id)
  end

  test "anonymous image reads cannot initiate an owner or sign-in workflow" do
    get base_app_dashboard_avatar_image_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :unauthorized
    assert_empty response.body
    assert_nil response.location
  end

  test "verified RP image GET and HEAD refuse missing authority without a cacheable image or session write" do
    original_session = @rp_session.reload.attributes
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: @rp_session.id)
    original_selection = selection.attributes
    image_headers = @headers.merge("Accept" => "image/png", "If-None-Match" => '"previous-owner-image"')

    get base_app_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_empty response.body
    assert_nil response.headers["ETag"]
    assert_nil response.location
    head base_app_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_empty response.body
    assert_nil response.headers["ETag"]
    assert_equal original_session, @rp_session.reload.attributes
    assert_equal original_selection, selection.reload.attributes
  end
end
