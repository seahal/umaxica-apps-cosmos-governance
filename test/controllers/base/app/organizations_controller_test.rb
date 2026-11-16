# frozen_string_literal: true

require "test_helper"

class Base::App::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "organization reads use the active RP session and Governance-owned membership authority" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(client, host:)
    original = bootstrap.collective.reload.attributes

    paths = [
      base_app_organizations_url(ri: "jp", host:),
      base_app_organization_url(bootstrap.collective.public_id, ri: "jp", host:),
      base_app_organization_url("nonexistent", ri: "jp", host:),
    ]
    paths.each_with_index do |path, index|
      get path, headers: headers

      if index == 2
        assert_response :not_found
      else
        assert_response :success
      end
      assert_includes response.headers["Cache-Control"], "no-store" if index < 2
    end

    assert_equal original, bootstrap.collective.reload.attributes
  end

  test "a foreign organization's membership data stays undisclosed" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    foreign = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
    before = foreign.collective.reload.attributes
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(client, host:)

    get base_app_organization_url(foreign.collective.public_id, ri: "jp", host:), headers: headers

    assert_response :not_found
    assert_equal before, foreign.collective.reload.attributes
  end
end
