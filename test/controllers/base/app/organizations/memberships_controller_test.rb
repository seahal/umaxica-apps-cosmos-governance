# frozen_string_literal: true

require "test_helper"

class Base::App::Organizations::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @membership = PersonaMembership.find_by!(persona_id: @bootstrap.account.id, enterprise_id: @bootstrap.collective.id)
    @organization = @bootstrap.collective.public_id
    @headers = as_user_headers(@client, host: @host)
  end

  test "anonymous membership access refuses without an interactive OP workflow" do
    get base_app_organization_memberships_url(@organization, ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :unauthorized
    assert_nil response.location
  end

  test "membership lists details and forms refuse missing owner authority" do
    original = @membership.reload.attributes

    [base_app_organization_memberships_url(@organization, ri: "jp", host: @host),
     base_app_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host),
     new_base_app_organization_membership_url(@organization, ri: "jp", host: @host),
     edit_base_app_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host),].each do |path|
      get path, headers: @headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
    end
    assert_equal original, @membership.reload.attributes
  end

  test "membership creation changes and removal cannot mutate Gov rows without owner authority" do
    original = @membership.reload.attributes
    count = PersonaMembership.count

    post base_app_organization_memberships_url(@organization, ri: "jp", host: @host), headers: @headers

    assert_response :service_unavailable
    patch base_app_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host), headers: @headers

    assert_response :service_unavailable
    delete base_app_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host), headers: @headers

    assert_response :service_unavailable
    assert_equal count, PersonaMembership.count
    assert_equal original, @membership.reload.attributes
  end
end
