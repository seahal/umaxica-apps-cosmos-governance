# frozen_string_literal: true

require "test_helper"

class BaseSharedRpCellSelectionTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  test "shared Base APP accepts its live local RP session and sends anonymous requests to its sign entry" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(clients(:one), host:)

    get base_app_verification_url(ri: "jp", host:), headers: headers

    assert_response :success

    post base_app_verification_url(ri: "jp", host:), params: { return_target: "/identity" }, headers: headers

    assert_response :service_unavailable
    assert_equal "private, no-store", response.headers["Cache-Control"]

    headers["Cookie"] = headers.fetch("Cookie").split("; ").reject do |pair|
      pair.start_with?("#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=")
    end.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
    get base_app_verification_url(ri: "jp", host:), headers: headers

    assert_response :see_other
    assert_redirected_to base_app_sign_show_path(ri: "jp", target_link_uri: "/verification")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "shared Base ORG accepts its live local RP session and sends anonymous requests to its sign entry" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    headers = as_staff_headers(operators(:one), host:)

    get base_org_verification_url(ri: "jp", host:), headers: headers

    assert_response :success

    post base_org_verification_url(ri: "jp", host:), params: { return_target: "/identity" }, headers: headers

    assert_response :service_unavailable
    assert_equal "private, no-store", response.headers["Cache-Control"]

    headers["Cookie"] = headers.fetch("Cookie").split("; ").reject do |pair|
      pair.start_with?("#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=")
    end.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
    get base_org_verification_url(ri: "jp", host:), headers: headers

    assert_response :see_other
    assert_redirected_to base_org_sign_show_path(ri: "jp", target_link_uri: "/verification")
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
