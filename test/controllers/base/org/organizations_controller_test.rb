# frozen_string_literal: true

require "test_helper"

class Base::Org::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @staff = operators(:one)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
    @headers = as_staff_headers(@staff, host: @host)
  end

  test "index reads Governance-owned organizations for the active RP session" do
    get "/organizations?ri=jp", headers: @headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "the active RP session can read its own organization" do
    get "/organizations/#{@bootstrap.collective.public_id}?ri=jp", headers: @headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "another operator's organization is not disclosed" do
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operators(:two))
    before = other.collective.reload.attributes
    get "/organizations/#{other.collective.public_id}?ri=jp", headers: @headers

    assert_response :not_found
    assert_not response.parsed_body.key?("props")
    assert_not response.parsed_body.key?("organization")
    assert_equal before, other.collective.reload.attributes
  end

  test "unknown public id is not disclosed" do
    get "/organizations/unknown-record?ri=jp", headers: @headers

    assert_response :not_found
  end

  test "Governance organizations policy preserves ownership" do
    other_staff = operators(:two)
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_staff)

    assert OrganizationPolicy.new(@bootstrap.collective, user: @staff).apply(:show?)
    assert_not OrganizationPolicy.new(other.collective, user: @staff).apply(:show?)
  end
end
