# frozen_string_literal: true

require "test_helper"

class BaseSharedRpCellSelectionTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  test "shared Base APP accepts only its live local RP session and refuses missing Access issuance" do
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
    get base_app_verification_url(ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_nil response.location
  end

  test "shared Base ORG accepts only its live local RP session and refuses missing Access issuance" do
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
    get base_org_verification_url(ri: "jp", host:), headers: headers

    assert_response :unauthorized
    assert_nil response.location
  end
end
