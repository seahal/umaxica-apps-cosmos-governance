# frozen_string_literal: true

require "test_helper"

class WithdrawalCeremonyReentryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "GET reentry page uses the generic description without creating a ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    assert_no_difference ["ClientWithdrawalCeremony.count", "ActionMailer::Base.deliveries.count"] do
      get new_base_app_identity_withdrawal_session_url(ri: "jp", host:)
    end

    assert_response :success
    assert_includes response.body, I18n.t("withdrawal_ceremony_reentry.generic_message")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "withdrawal reentry exposes missing Access authority without issuing mail or changing Governance state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    [nil, "", "unknown@example.test"].each do |address|
      assert_no_difference ["Client.count", "ClientWithdrawalCeremony.count", "ActionMailer::Base.deliveries.count"] do
        assert_no_enqueued_jobs do
          post base_app_identity_withdrawal_session_url(ri: "jp", host:),
               params: { withdrawal_reentry: { address: } }
        end
      end

      assert_response :service_unavailable
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil response.location
      assert_nil cookies[AuthenticationCookieName.access]
      assert_nil cookies[AuthenticationCookieName.refresh]
    end
  end
end
