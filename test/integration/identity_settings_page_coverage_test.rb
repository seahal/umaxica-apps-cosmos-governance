# frozen_string_literal: true

require "test_helper"

class IdentitySettingsPageCoverageTest < ActionDispatch::IntegrationTest
  test "operator reads Gov contact inventories using its local RP session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = OperatorTelephone.create!(
      staff: operator, number: "+819066610001", staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
    email = OperatorEmail.create!(
      staff: operator, address: "org-coverage@example.test", staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "org-contact-#{index}", external_id: SecureRandom.uuid,
        public_key: "org-contact-key-#{index}", description: "Contact read fixture",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(operator, host:)

    get base_org_identity_telephones_url(ri: "jp", host:), headers: headers

    assert_response :success
    assert_includes response.body, telephone.number
    get base_org_identity_emails_url(ri: "jp", host:), headers: headers

    assert_response :success
    assert_includes response.body, email.address
  end

  test "operator secret management reports absent Access authority without credential changes" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    secret = OperatorSecretCredential.create!(
      staff: operator, name: "Existing", password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    original = secret.attributes
    headers = as_staff_headers(operator, host:)

    [base_org_identity_secrets_url(ri: "jp", host:),
     base_org_identity_secret_url(secret.public_id, ri: "jp", host:),
     edit_base_org_identity_secret_url(secret.public_id, ri: "jp", host:),
     new_base_org_identity_secret_url(ri: "jp", host:),].each do |path|
      get path, headers: headers

      assert_response :service_unavailable
      assert_includes response.headers["Cache-Control"], "no-store"
    end
    assert_no_difference -> { OperatorSecretCredential.count } do
      post base_org_identity_secrets_url(ri: "jp", host:),
           params: { staff_secret_credential: { name: "Refused", enabled: "1" } }, headers: headers
    end
    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    patch base_org_identity_secret_url(secret.public_id, ri: "jp", host:),
          params: { staff_secret_credential: { name: "Refused", enabled: "1" } }, headers: headers

    assert_response :service_unavailable
    assert_equal original, secret.reload.attributes
    delete base_org_identity_secret_url(secret.public_id, ri: "jp", host:), headers: headers

    assert_response :service_unavailable
    assert_equal original, secret.reload.attributes
  end

  test "client reads all Gov telephone records through its local RP session" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    telephone = ClientTelephone.create!(
      user: client, number: "+819077710001", user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    extra = ClientTelephone.create!(
      user: client, number: "+819077710002", user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )
    headers = as_user_headers(client, host:)

    get base_app_identity_telephones_url(ri: "jp", host:), headers: headers

    assert_response :success
    props = JSON.parse(css_select("script[data-page='app']").first.text).fetch("props")

    assert_equal [telephone.public_id, extra.public_id], props.fetch("telephones").map { |entry|
      entry.fetch("public_id")
    }
  end
end
