# frozen_string_literal: true

require "test_helper"

class StaffLifecycleBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :operators

  test "ORG withdrawal requires supported step-up and does not deactivate on entry" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    2.times do
      OperatorPasskey.create!(
        staff: actor, external_id: SecureRandom.alphanumeric(21), webauthn_id: SecureRandom.alphanumeric(21),
        public_key: "staff-info-public-key", sign_count: 0, description: "Staff information", status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(actor, host:)

    get base_org_identity_withdrawal_url(ri: "jp", host:), headers: headers

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_nil actor.reload.deactivated_at
  end

  test "ORG has no destructive self-service withdrawal verbs" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    actor = operators(:one)
    headers = as_staff_headers(actor, host:)

    patch base_org_identity_withdrawal_url(ri: "jp", host:), params: { ack_deactivate_today: "1" }, headers: headers

    assert_response :not_found

    delete base_org_identity_withdrawal_url(ri: "jp", host:), headers: headers

    assert_response :not_found
    assert_nil actor.reload.deactivated_at
  end
end
