# typed: false
# frozen_string_literal: true

require "test_helper"

# Withdrawal scheduling and the pages the withdrawal ceremony unlocks on the app
# identity surface: the recovery page, the early personal-data erasure request,
# its status page, and ending the ceremony session.
class Base::App::Identity::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @headers = as_user_headers(@client, host: @host)
  end

  test "new requires fresh evidence before showing the withdrawal entry" do
    get new_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_not ClientWithdrawalFlow.exists?(client_id: @client.id)
  end

  test "acknowledging the schedule does not bypass fresh evidence" do
    get new_base_app_identity_withdrawal_url(ri: "jp", host: @host, ack_schedule_purge: "1"), headers: @headers

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_not ClientWithdrawalFlow.exists?(client_id: @client.id)
  end

  test "update without acknowledging the purge schedule leaves the client active" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "0" }, headers: @headers

    assert_response :unauthorized
    assert_not ClientWithdrawalFlow.exists?(client_id: @client.id)
  end

  test "update with the purge acknowledgement still requires fresh evidence" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers

    assert_response :unauthorized
    assert_not ClientWithdrawalFlow.exists?(client_id: @client.id)
  end

  test "recovery page and privacy erasure pages are reachable once the ceremony is issued" do
    past = @client.class.database_now - 2.days
    @client.update!(
      created_at: past - 1.minute, withdrawal_started_at: past, deactivated_at: past, discard_at: past,
      purge_eligible_at: 29.days.from_now,
    )
    ClientWithdrawalFlow.create!(
      client: @client, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
    )
    ceremony = ClientWithdrawalCeremony.issue!(subject: @client, purpose: "status")
    cookie_name = AuthenticationCookieName.with_host_prefix(
      WithdrawalCeremonyCookie::COOKIE_BASENAME, production: JitSessionCookieConfig.force_secure?,
    )
    cookies[cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success

    get new_base_app_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_equal "Early personal data erasure", inertia_props.fetch("title")

    assert_no_difference("ClientPrivacyRequest.count") do
      post base_app_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }
    end

    assert_response :forbidden

    get base_app_identity_privacy_erasure_status_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_nil inertia_props.fetch("privacy_request")
  end

  test "the withdrawal ceremony session can be ended from the recovery page" do
    past = @client.class.database_now - 2.days
    @client.update!(
      created_at: past - 1.minute, withdrawal_started_at: past, deactivated_at: past, discard_at: past,
      purge_eligible_at: 29.days.from_now,
    )
    ClientWithdrawalFlow.create!(
      client: @client, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
    )
    ceremony = ClientWithdrawalCeremony.issue!(subject: @client, purpose: "status")
    cookie_name = AuthenticationCookieName.with_host_prefix(
      WithdrawalCeremonyCookie::COOKIE_BASENAME, production: JitSessionCookieConfig.force_secure?,
    )
    cookies[cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    delete base_app_identity_withdrawal_session_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect
  end

  test "deactivation without fresh evidence preserves the active actor and audit history" do
    ClientWithdrawalFlow.create!(
      client: @client, status_id: ClientWithdrawalFlowStatus::REQUESTED,
      began_at: Client.database_now,
    )
    ceremonies_before = ClientWithdrawalCeremony.count

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    assert_response :unauthorized
    assert_nil response.location
    assert_nil @client.reload.deactivated_at
    assert_not AppIdentityAuthenticationEvent.exists?(actor_ref: @client.id.to_s, reason: "withdrawal_suspend")
    assert_equal ceremonies_before, ClientWithdrawalCeremony.count
  end

  test "ending the withdrawal ceremony session clears Inertia history on the next page" do
    past = @client.class.database_now - 2.days
    @client.update!(
      created_at: past - 1.minute, withdrawal_started_at: past, deactivated_at: past, discard_at: past,
      purge_eligible_at: 29.days.from_now,
    )
    ClientWithdrawalFlow.create!(
      client: @client, status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: past, discard_at: Float::INFINITY,
    )
    ceremony = ClientWithdrawalCeremony.issue!(subject: @client, purpose: "status")
    cookie_name = AuthenticationCookieName.with_host_prefix(
      WithdrawalCeremonyCookie::COOKIE_BASENAME, production: JitSessionCookieConfig.force_secure?,
    )
    cookies[cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"
    delete base_app_identity_withdrawal_session_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :see_other
    get base_app_root_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert inertia_page.fetch("clearHistory")
  end
end
