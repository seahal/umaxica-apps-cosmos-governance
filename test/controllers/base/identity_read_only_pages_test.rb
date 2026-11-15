# typed: false
# frozen_string_literal: true

require "test_helper"

# Read-only identity pages that every surface serves to its own authenticated
# principal: account standing, activity log, and birthdate. Each remaining
# surface is asserted separately so a page that regresses on one surface cannot
# hide behind another.
class BaseIdentityReadOnlyPagesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels, :operators,
           :operator_statuses, :operator_chronicle_events, :operator_chronicle_levels

  test "app standing page reads Governance enforcement state for a verified client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)

    headers = as_user_headers(client, host: host)
    get base_app_identity_standing_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_kind_of String, inertia_props.fetch("status_label")
    assert_kind_of Array, inertia_props.fetch("decisions")
  end

  test "org standing page reads Governance enforcement state for a verified operator" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)

    as_staff_headers(operator, host: host)

    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "read-fixture-#{SecureRandom.uuid}", external_id: SecureRandom.uuid,
        public_key: "read-fixture-key-#{index}", description: "Read fixture", status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(operator, host: host)
    get base_org_identity_standing_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_kind_of String, inertia_props.fetch("status_label")
    assert_kind_of Array, inertia_props.fetch("decisions")
  end

  test "app activity log lists only normalized activity for the signed-in client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    # Chronicle records can outlive the principal transaction in parallel workers.
    client = Client.create!(
      id: 8_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: client.id.to_s, subject_type: "Client", event_id: ClientChronicleEvent::LOGIN_SUCCESS,
        context: {
          provider: "google",
          auth_method: "social",
          oidc_client_id: "private-client-id",
          "sign-rp": "internal-rp",
          social_session_limitation: "private-policy",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
        },
        ip_address: "10.2.3.4", occurred_at: 10.minutes.ago,
      )
      ClientChronicle.create!(
        subject_id: client.id.to_s, subject_type: "Client", event_id: ClientChronicleEvent::TOKEN_REFRESHED,
        context: { secret: "refresh-secret-sentinel" }, occurred_at: 1.minute.ago,
      )
    end

    headers = as_user_headers(client, host: host)
    get base_app_identity_activities_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_equal %w(occurred_at activity device source risk), inertia_props.fetch("columns").keys
    rows = inertia_props.fetch("activities")

    assert_equal 1, rows.length
    assert_equal "Googleでログイン", rows.first.fetch("activity")
    assert_equal "低", rows.first.fetch("risk")
    %w(10.2.3.4 private-client-id internal-rp private-policy refresh-secret-sentinel).each do |value|
      assert_not_includes response.body, value
    end
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "injected Chronicle failure" }
    Chronicle.stub(:where, failure) do
      get base_app_identity_activities_url(ri: "jp", host: host), headers: headers

      assert_response :service_unavailable
      assert_includes response.body, I18n.t("base.shared.identity.activities.unavailable", locale: :ja)
    end
  end

  test "org activity log lists the operator's own recorded activity" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)

    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::LOGIN_SUCCESS,
        context: {
          provider: "google",
          auth_method: "social",
          oidc_client_id: "private-operator-client",
          "sign-rp": "internal-operator-rp",
          social_session_limitation: "private-policy",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
        },
        ip_address: "172.16.0.2", occurred_at: 10.minutes.ago,
      )
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::LOGIN_FAILED,
        context: { auth_method: "internal-auth-value" }, ip_address: "10.0.0.5", occurred_at: 5.minutes.ago,
      )
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::TOKEN_REFRESHED,
        context: { secret: "refresh-secret-sentinel" }, occurred_at: 1.minute.ago,
      )
    end

    as_staff_headers(operator, host: host)

    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "read-fixture-#{SecureRandom.uuid}", external_id: SecureRandom.uuid,
        public_key: "read-fixture-key-#{index}", description: "Read fixture", status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(operator, host: host)
    get base_org_identity_activities_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_equal I18n.t("base.shared.identity.activities.title"), inertia_props.fetch("title")
    assert_equal %w(occurred_at activity device source risk), inertia_props.fetch("columns").keys
    rows = inertia_props.fetch("activities")

    assert_equal ["ログインに失敗", "Googleでログイン"], rows.map { |row| row.fetch("activity") }
    assert_equal ["中", "低"], rows.map { |row| row.fetch("risk") }
    assert_equal %w(occurred_at activity device source risk risk_rank), rows.last.keys
    %w(172.16.0.2 10.0.0.5 private-operator-client internal-operator-rp private-policy internal-auth-value
       refresh-secret-sentinel).each do |value|
      assert_not_includes response.body, value
    end
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "injected Chronicle failure" }
    OperatorChronicle.stub(:where, failure) do
      get base_org_identity_activities_url(ri: "jp", host: host), headers: headers

      assert_response :service_unavailable
      assert_includes response.body, I18n.t("base.shared.identity.activities.unavailable", locale: :ja)
    end
  end

  test "app birthdate reports unavailable authority without issuing authentication state" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    headers = as_user_headers(client, host: host)
    original = [RpStepUpState.count, RpStepUpAuditOutbox.count, ClientPasskey.count, ClientTotpCredential.count]

    get base_app_identity_birthdate_url(ri: "jp", host: host), headers: headers

    assert_response :service_unavailable
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal original,
                 [RpStepUpState.count, RpStepUpAuditOutbox.count, ClientPasskey.count, ClientTotpCredential.count]
  end

  test "app standing page rejects an unauthenticated request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_identity_standing_url(ri: "jp", host: host),
        headers: { "Client-Agent" => "Mozilla/5.0", "Host" => host }

    assert_not_equal 200, response.status
  end
  test "app standing reads the active Governance decision without changing it" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    enforcement_case = AppEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: client.public_id,
      applied_by_operator_public_id: "standing-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )

    headers = as_user_headers(client, host: host)
    get base_app_identity_standing_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    decision_public_ids = inertia_props.fetch("decisions").map { |decision| decision.fetch("public_id") }

    assert_includes decision_public_ids, enforcement_case.public_id
    assert_equal "active", enforcement_case.reload.state
    assert_equal "abuse", enforcement_case.reason_code
    assert_predicate enforcement_case.expires_at, :present?
  end

  test "org standing reads the active Governance decision without changing it" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    enforcement_case = OrgEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: operator.public_id,
      applied_by_operator_public_id: "standing-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )

    2.times do |index|
      OperatorPasskey.create!(
        staff: operator, webauthn_id: "read-fixture-#{SecureRandom.uuid}", external_id: SecureRandom.uuid,
        public_key: "read-fixture-key-#{index}", description: "Read fixture", status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    headers = as_staff_headers(operator, host: host)
    get base_org_identity_standing_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    decision_public_ids = inertia_props.fetch("decisions").map { |decision| decision.fetch("public_id") }

    assert_includes decision_public_ids, enforcement_case.public_id
    assert_equal "active", enforcement_case.reload.state
  end
end
