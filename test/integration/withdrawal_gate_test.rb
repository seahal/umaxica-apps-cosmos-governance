# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class WithdrawalGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host

    @deactivated_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    # The selector-ready graph exists before withdrawal starts, as it does for a real account;
    # Avatar provisioning rejects a principal whose withdrawal has already begun.
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @deactivated_user)
    @headers = as_user_headers(@deactivated_user, host: @host)

    @deactivated_user.update!(
      withdrawal_started_at: 1.day.ago,
      deactivated_at: Time.current,
      discard_at: Time.current,
      purge_eligible_at: 31.days.from_now,
    )
  end

  test "deactivated user accessing normal page redirects to withdrawal session entry" do
    get base_app_identity_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
        headers: @headers

    assert_response :redirect
    assert_redirected_to new_base_app_identity_withdrawal_session_path(ri: "jp")
  end

  test "deactivated user cannot access withdrawal pages through normal auth" do
    get(
      new_base_app_identity_withdrawal_url(
        ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      ),
      headers: @headers,
    )

    assert_response :unauthorized

    get(
      edit_base_app_identity_withdrawal_url(
        ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      ),
      headers: @headers,
    )

    assert_response :unauthorized
  end

  test "deactivated user accessing API returns 403" do
    get base_app_identity_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
        headers: @headers.merge("Accept" => "application/json")

    assert_response :forbidden
    json_response = response.parsed_body

    assert_equal "WITHDRAWAL_REQUIRED", json_response["error"]
  end

  test "normal user can access pages without withdrawal gate" do
    normal_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: normal_user)
    headers = as_user_headers(normal_user, host: @host)

    get base_app_identity_url(ri: "jp", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
        headers: headers

    assert_response :success
  end
end
