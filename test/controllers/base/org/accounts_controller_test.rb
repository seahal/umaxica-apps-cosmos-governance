# frozen_string_literal: true

require "test_helper"

class Base::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @staff = operators(:one)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
    @headers = as_staff_headers(@staff, host: @host)
  end

  test "index reads Governance-owned accounts for the active RP session" do
    get "/accounts?ri=jp", headers: @headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "the active RP session can read its own account" do
    get "/accounts/#{@bootstrap.account.public_id}?ri=jp", headers: @headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "another operator's account is not disclosed" do
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operators(:two))
    before = other.account.reload.attributes
    get "/accounts/#{other.account.public_id}?ri=jp", headers: @headers

    assert_response :not_found
    assert_not response.parsed_body.key?("props")
    assert_not response.parsed_body.key?("account")
    assert_equal before, other.account.reload.attributes
  end

  test "unknown public id is not disclosed" do
    get "/accounts/unknown-record?ri=jp", headers: @headers

    assert_response :not_found
  end

  test "Governance accounts policy preserves ownership" do
    other_staff = operators(:two)
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_staff)

    assert AccountPolicy.new(@bootstrap.account, user: @staff).apply(:show?)
    assert_not AccountPolicy.new(other.account, user: @staff).apply(:show?)
  end
end
