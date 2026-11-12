# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The withdrawal gate derives its redirect from the controller's surface family. An org
    # operator in the withdrawal lifecycle must land on the org withdrawal page; falling back to
    # the app page would send a staff session across the org/app trust boundary.
    class OrgWithdrawalGateInvariantTest < ActionDispatch::IntegrationTest
      fixtures :operators

      setup do
        @availability_flag = FqdnAvailabilityRegistry.flag_name_for(:base_staff)
        @availability_was_enabled = Flipper.enabled?(@availability_flag)
        Flipper.enable(@availability_flag)
      end

      teardown do
        @availability_was_enabled ? Flipper.enable(@availability_flag) : Flipper.disable(@availability_flag)
      end

      test "a closing operator on the Base org identity surface is redirected to withdrawal" do
        org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
        host! org_host
        operator = operators(:one)
        headers = as_staff_headers(operator, host: org_host)
        get base_org_selector_url(host: org_host), headers: headers, as: :json

        assert_response :success
        selector_result = response.parsed_body

        if selector_result.fetch("status") == "selection_required"
          candidate = selector_result.fetch("accounts").first

          assert_predicate candidate, :present?

          patch base_org_selector_url(host: org_host), params: candidate, headers: headers, as: :json

          assert_response :success
          assert_equal "selected", response.parsed_body.fetch("status")
        else
          assert_equal "selected", selector_result.fetch("status")
        end

        operator.update!(withdrawal_started_at: 1.hour.ago)

        get base_org_identity_url(ri: "jp"), headers: headers

        assert_predicate operator.reload, :closing?
        assert_response :redirect
        location = URI.parse(response.location).request_uri

        assert_equal base_org_identity_withdrawal_path(ri: "jp"), location
        assert_not_equal edit_base_app_identity_withdrawal_path(ri: "jp"), location
      end

      test "a closing operator cannot read protected JSON or change its selection" do
        org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
        host! org_host
        operator = operators(:one)
        headers = as_staff_headers(operator, host: org_host)
        operator.update!(withdrawal_started_at: 1.hour.ago)
        original_identity = operator.reload.attributes

        get base_org_identity_url(ri: "jp"), headers: headers, as: :json

        assert_response :forbidden
        assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body.fetch("error")

        patch base_org_selector_url(ri: "jp"), params: {}, headers: headers, as: :json

        assert_response :forbidden
        assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body.fetch("error")
        assert_equal original_identity, operator.reload.attributes
      end

      test "a reserved closing operator cannot use the withdrawal redirect as authentication" do
        org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
        host! org_host
        operator = operators(:one)
        headers = as_staff_headers(operator, host: org_host)
        operator.update!(withdrawal_started_at: 1.hour.ago, status_id: OperatorStatus::RESERVED)

        get base_org_identity_url(ri: "jp"), headers: headers

        assert_response :unauthorized
        assert_nil response.location
      end

      test "an active operator can open the Base org identity surface" do
        org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
        host! org_host

        get base_org_identity_url(ri: "jp"), headers: as_staff_headers(operators(:one), host: org_host)

        assert_response :success
      end
    end
  end
end
