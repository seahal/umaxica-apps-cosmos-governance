# frozen_string_literal: true

require "test_helper"

class Base::App::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @headers = as_user_headers(@client, host: @host)
  end

  test "anonymous accounts access cannot create an RP session or initiate sign-in" do
    assert_no_difference -> { RpBaseAppSession.count } do
      get base_app_accounts_url(ri: "jp", host: @host), headers: host_headers(@host)
    end
    assert_response :unauthorized
    assert_nil response.location
  end

  test "account reads require the unavailable owner authority even with a verified RP session" do
    original = @bootstrap.account.reload.attributes

    [base_app_accounts_url(ri: "jp", host: @host),
     base_app_account_url(@bootstrap.account.public_id, ri: "jp", host: @host),].each do |path|
      get path, headers: @headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_nil response.location
    end
    assert_equal original, @bootstrap.account.reload.attributes
  end

  test "unavailable account reads do not reveal whether a foreign account exists" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    foreign = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)

    [foreign.account.public_id, "nonexistent"].each do |reference|
      get base_app_account_url(reference, ri: "jp", host: @host), headers: @headers

      assert_response :service_unavailable
      assert_not_includes response.body, foreign.account.public_id
    end
  end
end
