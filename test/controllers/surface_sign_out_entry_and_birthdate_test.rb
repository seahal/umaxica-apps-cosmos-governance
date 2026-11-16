# frozen_string_literal: true

require "test_helper"

class SurfaceSignOutEntryAndBirthdateTest < ActionDispatch::IntegrationTest
  test "stored ORG birthdate remains private without fresh Access step-up evidence" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    operator.update!(birthdate: "1985-03-04")
    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "birthdate-boundary-#{index}", external_id: SecureRandom.uuid,
        public_key: "birthdate-boundary-key-#{index}", description: "Birthdate boundary",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(operator, host: host).merge(
      "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Accept" => "text/html",
    )

    get base_org_identity_birthdate_url(ri: "jp", host: host), headers: headers

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_not_includes response.body, "1985-03-04"
    assert_equal "1985-03-04", operator.reload.birthdate
  end
end
