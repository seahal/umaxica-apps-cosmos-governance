# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseSettingsAuthoritySlice1GTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_chronicle_events, :client_chronicle_levels

  test "base app settings shell route is removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/settings",
        method: :get,
      )
    end
  end

  test "base app activities list only current user entries" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    user = clients(:one)
    other_user = clients(:two)
    ChronicleRecord.connected_to(role: :writing) { ClientChronicle.delete_all }
    create_user_audit(user: user, tag: "my-login-event")
    create_user_audit(user: user, tag: "own-failed-event", event_id: ClientChronicleEvent::LOGIN_FAILED)
    create_user_audit(user: user, tag: "refresh-internal", event_id: ClientChronicleEvent::TOKEN_REFRESHED)
    create_user_audit(user: other_user, tag: "other-login-event")

    headers = as_user_headers(user, host: host)
    get base_app_identity_activities_url(ri: "jp", host: host), headers: headers

    assert_response :success
    rows = inertia_props.fetch("activities")

    assert_equal 2, rows.size
    assert_equal ["ログインに失敗", "ログイン"], rows.map { |row| row.fetch("activity") }
    assert_equal ["中", "低"], rows.map { |row| row.fetch("risk") }
    assert_equal %w(occurred_at activity device source risk risk_rank), rows.first.keys
    assert_not_includes response.body, "my-login-event"
    assert_not_includes response.body, "own-failed-event"
    assert_not_includes response.body, "refresh-internal"
    assert_not_includes response.body, "other-login-event"
  end

  test "base com settings shell route is removed and org settings belongs to the base console" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_CORPORATE_URL")}/settings",
        method: :get,
      )
    end

    assert_equal(
      { controller: "base/org/settings", action: "show" },
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_STAFF_URL")}/settings",
        method: :get,
      ),
    )
  end

  test "base org identity owns non-ceremony identity settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      base_org_identity_email
      base_org_identity_telephone
      base_org_identity_birthdate
      base_org_identity_secret
      base_org_identity_activit
      base_org_identity_withdrawal
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must exist"
    end
  end

  test "base com no longer owns identity or withdrawal routes" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    [
      ["/identity/withdrawal/new", :get],
      ["/identity/withdrawal/edit", :get],
      ["/identity/withdrawal", :post],
      ["/identity/withdrawal", :patch],
      ["/identity/withdrawal", :delete],
      ["/identity/emails", :get],
    ].each do |path, method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
      end
    end
  end

  test "base org withdrawal is informational get only" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    assert_equal(
      { controller: "base/org/identity/withdrawals", action: "show" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :get),
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :delete)
    end
  end

  test "base org identity routes load controllers" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get base_org_identity_emails_url(ri: "jp", host: host)

    assert_not_equal 404, response.status
  end

  private

  def host_headers(host = nil)
    host.present? ? { "Host" => host } : {}
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  # Base shares its production origin with Acme (both `https://www.umaxica.<tld>`), so the
  # issuer namespace cannot be inferred from a host substring like "base". Match against the
  # actual configured Base hosts first; fall back to substring heuristics for surfaces whose
  # hosts are texually distinct (acme/core/sign).
  def create_user_audit(user:, tag:, event_id: ClientChronicleEvent::LOGGED_IN)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: user.id,
        subject_type: "Client",
        event_id: event_id,
        context: { tag: tag },
        occurred_at: Time.current,
      )
    end
  end
end
