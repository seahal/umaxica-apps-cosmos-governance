# frozen_string_literal: true

require "test_helper"

class Base::Org::Organizations::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @organization = @bootstrap.collective.public_id
    @membership = AgentMembership.find_by!(agent_id: @bootstrap.account.id, bureau_id: @bootstrap.collective.id)
    @headers = as_staff_headers(@operator, host: @host)
  end

  test "anonymous membership access refuses without starting OP sign-in" do
    get base_org_organization_memberships_url(@organization, ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :see_other
    target = URI.parse(response.location)

    assert_equal URI.parse(base_org_sign_show_path(ri: "jp")).path, target.path
    assert_includes [nil, request.host], target.host
  end

  test "ORG membership reads use Governance authority and preserve ownership boundaries" do
    original = @membership.reload.attributes

    get base_org_organization_memberships_url(@organization, ri: "jp", host: @host), headers: @headers, as: :json

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.parsed_body.fetch("memberships").map { |row| row.fetch("id") }, @membership.id
    assert_equal @bootstrap.account.public_id,
                 response.parsed_body.fetch("memberships").sole.fetch("agent_public_id")

    get base_org_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host),
        headers: @headers, as: :json

    assert_response :success
    assert_equal @membership.id, response.parsed_body.fetch("id")

    get base_org_organization_membership_url("foreign-org", "foreign-member", ri: "jp", host: @host),
        headers: @headers, as: :json

    assert_response :not_found
    assert_equal original, @membership.reload.attributes
  end

  test "pagination accepts nearest values below and at the limit before its owner dependency" do
    [OrgAdministrationPage::MAX_PAGE - 1, OrgAdministrationPage::MAX_PAGE].each do |page|
      get base_org_organization_memberships_url(@organization, page: page, ri: "jp", host: @host),
          headers: @headers, as: :json

      assert_response :success
    end
  end

  test "pagination rejects zero negative malformed and immediately above-limit values" do
    ["0", "-1", "1x", (OrgAdministrationPage::MAX_PAGE + 1).to_s].each do |page|
      get base_org_organization_memberships_url(@organization, page: page, ri: "jp", host: @host),
          headers: @headers, as: :json

      assert_response :bad_request
    end
  end

  test "ORG membership changes remain unrouted and preserve the local membership" do
    original = @membership.reload.attributes
    count = AgentMembership.count

    post base_org_organization_memberships_url(@organization, ri: "jp", host: @host), headers: @headers

    assert_response :not_found
    patch base_org_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host), headers: @headers

    assert_response :not_found
    delete base_org_organization_membership_url(@organization, @membership.id, ri: "jp", host: @host), headers: @headers

    assert_response :not_found
    assert_equal count, AgentMembership.count
    assert_equal original, @membership.reload.attributes
  end
end
