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

  test "anonymous accounts access is sent to the neutral sign entry without creating an RP session" do
    assert_no_difference -> { RpBaseAppSession.count } do
      get base_app_accounts_url(ri: "jp", host: @host), headers: host_headers(@host)
    end

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal "/sign", location.path
    assert_equal({ "ri" => "jp", "target_link_uri" => "/accounts" }, Rack::Utils.parse_query(location.query))
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "account reads use the active RP session and Governance owner without changing account data" do
    original = @bootstrap.account.reload.attributes

    [base_app_accounts_url(ri: "jp", host: @host),
     base_app_account_url(@bootstrap.account.public_id, ri: "jp", host: @host),].each do |path|
      get path, headers: @headers

      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_nil response.location
    end
    assert_equal original, @bootstrap.account.reload.attributes
  end

  test "account reads do not reveal whether a foreign account exists" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    foreign = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)

    [foreign.account.public_id, "nonexistent"].each do |reference|
      get base_app_account_url(reference, ri: "jp", host: @host), headers: @headers

      assert_response :not_found
    end
  end
end
