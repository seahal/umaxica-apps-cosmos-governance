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

  test "verified RP image GET and HEAD use Governance authority with private revalidation and no session write" do
    original_session = @rp_session.reload.attributes
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: @rp_session.id)
    original_selection = selection.attributes
    image_headers = @headers.merge("Accept" => "image/png", "If-None-Match" => '"previous-owner-image"')

    get base_app_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :success
    assert_equal "max-age=0, private, must-revalidate", response.headers["Cache-Control"]
    assert_equal "image/png", response.media_type
    assert_predicate response.headers["ETag"], :present?
    assert_nil response.location
    head base_app_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :success
    assert_equal "max-age=0, private, must-revalidate", response.headers["Cache-Control"]
    assert_predicate response.headers["ETag"], :present?
    assert_equal original_session, @rp_session.reload.attributes
    assert_equal original_selection, selection.reload.attributes
  end
end
