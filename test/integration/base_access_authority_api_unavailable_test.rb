# frozen_string_literal: true

require "test_helper"

class BaseAccessAuthorityApiUnavailableTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  CLIENT_HEADERS = {
    "Authorization" => "Bearer invalid-governance-api-token",
  }.freeze

  test "APP identity and Avatar authority routes refuse an invalid Governance bearer before exposing data" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    [
      [:get, "/api/v0/identity/standing"],
      [:get, "/api/v0/identity/selection"],
      [:get, "/api/v0/avatar/app/selected-image"],
      [:get, "/api/v0/avatar/app/avatars"],
      [:post, "/api/v0/avatar/app/avatars"],
      [:get, "/api/v0/avatar/app/avatars/avatar-reference"],
      [:patch, "/api/v0/avatar/app/avatars/avatar-reference"],
      [:put, "/api/v0/avatar/app/avatars/avatar-reference"],
      [:post, "/api/v0/avatar/app/avatars/avatar-reference/follows"],
      [:delete, "/api/v0/avatar/app/avatars/avatar-reference/blocks"],
      [:post, "/api/v0/avatar/app/ownership-transfers"],
      [:post, "/api/v0/avatar/app/ownership-transfers/transfer-reference/accept"],
      [:post, "/api/v0/avatar/app/ownership-transfers/transfer-reference/cancel"],
      [:post, "/api/v0/avatar/app/groups/group-reference/avatar-memberships"],
      [:patch, "/api/v0/avatar/app/groups/group-reference/avatar-memberships/membership-reference"],
      [:put, "/api/v0/avatar/app/groups/group-reference/avatar-memberships/membership-reference"],
      [:delete, "/api/v0/avatar/app/groups/group-reference/avatar-memberships/membership-reference"],
      [:get, "/api/v0/avatar/app/groups"],
      [:post, "/api/v0/avatar/app/groups"],
      [:get, "/api/v0/avatar/app/groups/group-reference"],
      [:patch, "/api/v0/avatar/app/groups/group-reference"],
      [:put, "/api/v0/avatar/app/groups/group-reference"],
      [:delete, "/api/v0/avatar/app/groups/group-reference"],
    ].each { |method, path| assert_invalid_governance_bearer(method, path, "APP") }
  end

  test "invalid Governance bearer is refused across ORG identity, Avatar, IAM and Support routes" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")

    [
      [:get, "/api/v0/identity/standing"],
      [:get, "/api/v0/identity/selection"],
      [:get, "/api/v0/avatar/org/selected-image"],
      [:get, "/api/v0/avatar/org/selected-avatar"],
      [:patch, "/api/v0/avatar/org/selected-avatar"],
      [:delete, "/api/v0/avatar/org/selected-avatar"],
      [:post, "/api/v0/avatar/org/ownership-transfers"],
      [:post, "/api/v0/avatar/org/ownership-transfers/transfer-reference/accept"],
      [:post, "/api/v0/avatar/org/ownership-transfers/transfer-reference/cancel"],
      [:get, "/api/v0/iam/grants"],
      [:get, "/api/v0/iam/grant-screen"],
      [:get, "/api/v0/iam/grants/grant-reference"],
      [:post, "/api/v0/iam/grants/grant-reference/revocation"],
      [:get, "/api/v0/support"],
      [:get, "/api/v0/support/app/accounts"],
      [:get, "/api/v0/support/app/accounts/account-reference"],
      [:get, "/api/v0/support/app/accounts/account-reference/revocation-screen"],
      [:post, "/api/v0/support/app/accounts/account-reference/revocations"],
      [:get, "/api/v0/support/app/accounts/account-reference/revocations/00000000-0000-4000-8000-000000000001"],
      [:get, "/api/v0/support/app/enforcement_cases/case-reference/approval/new"],
      [:post, "/api/v0/support/app/enforcement_cases/case-reference/approval"],
      [:get, "/api/v0/support/app/enforcement_cases/case-reference/release/new"],
      [:post, "/api/v0/support/app/enforcement_cases/case-reference/release"],
      [:get, "/api/v0/support/app/enforcement_cases/case-reference/appeal_review/new"],
      [:post, "/api/v0/support/app/enforcement_cases/case-reference/appeal_review"],
      [:get, "/api/v0/support/app/enforcement_cases"],
      [:post, "/api/v0/support/app/enforcement_cases"],
      [:get, "/api/v0/support/app/enforcement_cases/new"],
      [:get, "/api/v0/support/app/enforcement_cases/case-reference"],
    ].each { |method, path| assert_invalid_governance_bearer(method, path, "ORG") }
  end

  private

  def assert_invalid_governance_bearer(method, path, realm)
    public_send(method, path, headers: CLIENT_HEADERS)

    assert_response :unauthorized, "#{method.upcase} #{path} on #{realm}"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.location
  end
end
