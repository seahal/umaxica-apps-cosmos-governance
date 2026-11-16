# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "unavailable step-up start creates no state or successful admission log and exposes no identifiers" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "step-up-observability-passkey", sign_count: 0,
      description: "Step-up observability test passkey", status_id: ClientPasskeyStatus::ACTIVE,
    )
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!

    as_rp_cell("base-app-ww") do
      headers = as_user_headers(actor, host: base_host)
      local_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
        OidcRpBrowserCredentialContract::SESSION_COOKIE,
      )
      rp_session = RpBaseAppSession.find_by!(public_id: local_id)

      initial_states = RpStepUpState.count
      initial_audits = RpStepUpAuditOutbox.count
      post base_app_verification_path(ri: "jp"),
           params: { return_target: "/settings/birthdate" },
           headers: headers.merge("Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin")

      assert_response :service_unavailable
      assert_equal initial_states, RpStepUpState.count
      assert_equal initial_audits, RpStepUpAuditOutbox.count
      assert_not_includes @log.string, "auth.step_up.admission_issued"
      assert_not_includes @log.string, actor.public_id
      assert_not_includes @log.string, rp_session.public_id
      assert_not_includes @log.string, headers.fetch("Authorization")
    end
  end
end
