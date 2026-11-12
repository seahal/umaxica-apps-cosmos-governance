# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class WithdrawalGateInvariantTest < ActionDispatch::IntegrationTest
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      setup do
        @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        host! @host
        @availability_flag = FqdnAvailabilityRegistry.flag_name_for(:base_service)
        @availability_was_enabled = Flipper.enabled?(@availability_flag)
        Flipper.enable(@availability_flag)
      end

      teardown do
        @availability_was_enabled ? Flipper.enable(@availability_flag) : Flipper.disable(@availability_flag)
      end

      test "closing resource invalidates RP authentication on protected html routes" do
        as_rp_cell("base-app-ww") do
          user = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
            visibility_id: ClientVisibility::USER, created_at: 4.hours.ago,
          )
          headers = as_user_headers(user, host: @host)
          user.update!(withdrawal_started_at: 1.hour.ago)

          get base_app_identity_url(ri: "jp", host: @host),
              headers: headers

          assert request.cookies.key?(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
          assert_predicate user.reload, :closing?
          assert_response :unauthorized
        end
      end

      test "suspended resource gets withdrawal required on json protected routes" do
        user = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
          visibility_id: ClientVisibility::USER, created_at: 4.hours.ago,
        )
        headers = as_user_headers(user, host: @host)
        user.update!(
          withdrawal_started_at: 2.hours.ago, deactivated_at: 1.hour.ago,
          discard_at: 1.day.from_now, purge_eligible_at: 31.days.from_now,
        )

        get base_app_identity_url(ri: "jp", host: @host),
            headers: headers.merge("Accept" => "application/json")

        assert_response :forbidden
        assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body["error"]
      end

      test "terminated resource is redirected away from protected html routes" do
        user = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
          visibility_id: ClientVisibility::USER, created_at: 4.hours.ago,
        )
        headers = as_user_headers(user, host: @host)
        user.update!(
          withdrawal_started_at: 3.hours.ago, deactivated_at: 2.hours.ago, discard_at: 2.hours.ago,
          purge_eligible_at: 1.hour.ago, withdrawn_at: 1.hour.ago, terminated_at: 30.minutes.ago,
        )

        get base_app_identity_url(ri: "jp", host: @host),
            headers: headers

        assert_predicate user.reload, :terminated?
        assert_response :redirect
        assert_redirected_to new_base_app_identity_withdrawal_session_path(ri: "jp")
      end

      test "closing resource cannot reach withdrawal pages with an invalidated RP credential" do
        as_rp_cell("base-app-ww") do
          user = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
            visibility_id: ClientVisibility::USER, created_at: 4.hours.ago,
          )
          headers = as_user_headers(user, host: @host)
          user.update!(withdrawal_started_at: 1.hour.ago)

          get new_base_app_identity_withdrawal_url(ri: "jp"), headers: headers

          assert_predicate user.reload, :closing?
          assert_response :unauthorized
        end
      end

      test "application controllers do not skip the withdrawal gate" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/skip_before_action\s+:enforce_withdrawal_gate!/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Withdrawal gate skips require explicit invariant allowlist:\n#{offenders.join("\n")}"
      end
    end
  end
end
