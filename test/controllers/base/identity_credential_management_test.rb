# frozen_string_literal: true

require "test_helper"

class BaseIdentityCredentialManagementTest < ActionDispatch::IntegrationTest
  test "another registered credential does not replace Access proof for secret removal" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    removable = OperatorSecretCredential.create!(
      staff: operator, name: "Removable", password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    keeper = OperatorSecretCredential.create!(
      staff: operator, name: "Keeper", password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    original_removable = removable.reload.attributes
    original_keeper = keeper.reload.attributes
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    headers = as_staff_headers(operator, host: host)

    post base_org_identity_secret_removal_url(removable.public_id, ri: "jp", host: host), headers: headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal original_removable, removable.reload.attributes
    assert_equal original_keeper, keeper.reload.attributes
  end
end
