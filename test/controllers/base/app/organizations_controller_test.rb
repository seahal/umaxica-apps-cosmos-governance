# frozen_string_literal: true

require "test_helper"

class Base::App::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "organization reads cannot substitute local RP authentication for missing owner authority" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(client, host:)
    original = bootstrap.collective.reload.attributes

    [base_app_organizations_url(ri: "jp", host:),
     base_app_organization_url(bootstrap.collective.public_id, ri: "jp", host:),
     base_app_organization_url("nonexistent", ri: "jp", host:),].each do |path|
      get path, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_not_includes response.body, bootstrap.collective.public_id
    end
    assert_equal original, bootstrap.collective.reload.attributes
  end

  test "a foreign organization's membership data stays undisclosed while its owner is unavailable" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    foreign = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(client, host:)

    get base_app_organization_url(foreign.collective.public_id, ri: "jp", host:), headers: headers

    assert_response :service_unavailable
    assert_not_includes response.body, foreign.collective.public_id
    assert_not_includes response.body, foreign.account.public_id
  end
end
