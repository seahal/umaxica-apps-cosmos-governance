# typed: false
# frozen_string_literal: true

require "test_helper"

class Umaxica::Valkey::NamespacesTest < ActiveSupport::TestCase
  test "Valkey namespace keys include their authority prefix and optional test scope" do
    namespaces = Umaxica::Valkey::Namespaces

    assert_equal "auth_state:sign_out_notice", namespaces.sign_out_notices
    assert_equal "auth_state:rp_refresh", namespaces.rp_refresh
    assert_equal "otp-verification", namespaces.otp_verification
    assert_equal "auth_state:sign_out_notice:run-17:worker-2:test-3",
                 namespaces.sign_out_notices(suite_run_id: "run-17", worker_id: "worker-2", test_id: "test-3")
    assert_equal "auth_state:rp_refresh:run-17:worker-2:test-3",
                 namespaces.rp_refresh(suite_run_id: "run-17", worker_id: "worker-2", test_id: "test-3")
    assert_equal "otp-verification:run-17:worker-2:test-3",
                 namespaces.otp_verification(suite_run_id: "run-17", worker_id: "worker-2", test_id: "test-3")
  end
end
