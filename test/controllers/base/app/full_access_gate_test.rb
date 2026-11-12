# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::FullAccessGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
  end

  test "dashboard redirects authenticated unselected session to selector" do
    http_headers_2 = as_user_headers(@user, host: @host, select_available_app_persona: false)
    get base_app_dashboard_url(host: @host, ri: "jp"), headers: http_headers_2

    assert_redirected_to base_app_selector_path(ri: "jp")
  end

  test "selected dashboard reports unavailable Avatar authority after its local selector guard" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)

    http_headers_1 =
      begin
        as_user_headers(
          @user,
          host: @host,
        )
      end
    get base_app_dashboard_url(host: @host, ri: "jp"), headers: http_headers_1

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "dashboard requests selection as json when context is missing" do
    http_headers_0 = as_user_headers(@user, host: @host, select_available_app_persona: false)
    get base_app_dashboard_url(host: @host, ri: "jp"), headers: http_headers_0, as: :json

    assert_response :forbidden
    assert_equal "selection_required", response.parsed_body.fetch("status")
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::App::FullAccessGateTest
  private
end
