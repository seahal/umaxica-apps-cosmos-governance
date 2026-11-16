# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02BaseRpStateTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A02-12: Base Welcome and Selector work from RP credentials without an Auth Rails session" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    headers = as_user_headers(actor, host: base_host)
    ["/welcome?ri=jp", "/selector?ri=jp"].each do |path|
      browser = open_session
      browser.https!
      browser.host!(base_host)
      browser.get(path, headers:)

      if path.start_with?("/welcome")
        assert_equal 200, browser.response.status, path
      else
        assert_equal 302, browser.response.status, path
        assert_equal base_host, URI.parse(browser.response.location).host
        assert_equal "/switcher", URI.parse(browser.response.location).path
      end

      assert_nil browser.cookies["__Host-auth_sid"], "Base must not need the Auth ceremony cookie"
      assert_nil browser.cookies["auth_sid"], "Base must not need the Auth ceremony cookie"
    end
  end
end
