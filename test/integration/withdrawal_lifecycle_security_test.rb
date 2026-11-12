# frozen_string_literal: true

require "test_helper"

class WithdrawalLifecycleSecurityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Governance recovery eligibility retains its one hour and purge deadline boundaries" do
    now = Time.utc(2026, 11, 12, 12)
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER, created_at: now - 120.days,
      withdrawal_started_at: now - 3.hours, deactivated_at: now - 2.hours,
      discard_at: now + 31.days, purge_eligible_at: now + 31.days,
    )
    available = actor.recovery_available_at
    deadline = actor.recovery_deadline

    assert_not actor.can_recover?(now: available - 1.second)
    assert actor.can_recover?(now: available)
    assert actor.can_recover?(now: available + 1.second)
    assert actor.can_recover?(now: deadline - 1.second)
    assert_not actor.can_recover?(now: deadline)
    assert_not actor.can_recover?(now: deadline + 1.second)
  end

  test "missing Access reentry authority does not restore a suspended account or issue a ceremony" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER, created_at: 120.days.ago,
      withdrawal_started_at: 3.hours.ago, deactivated_at: 2.hours.ago,
      discard_at: 31.days.from_now, purge_eligible_at: 31.days.from_now,
    )
    original = actor.reload.attributes
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_no_difference "ClientWithdrawalCeremony.count" do
      post base_app_identity_withdrawal_session_path(ri: "jp"), params: { pass_code: "123456" }
    end

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, actor.reload.attributes
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end
end
