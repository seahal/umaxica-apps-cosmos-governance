# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold raise/return arms needed to clear the 90% branch floor.
class BranchCoverageBatch32ThresholdPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Health ok? status string arms" do
    ok = Health::CheckResult.new(check: :liveness, status: :ok, surface: "app")
    unready = Health::CheckResult.new(check: :liveness, status: :unready, surface: "app")

    assert_predicate ok, :ok?
    assert_not unready.ok?
    assert_equal "ok", ok.as_public_json[:status]
    assert_equal "unavailable", unready.as_public_json[:status]
  end

  test "SignRiskEnforcer disabled env and blank resource" do
    ENV["RISK_ENFORCEMENT_DISABLED"] = "true"
    begin
      assert_nil SignRiskEnforcer.call(Client.new(security_mode_id: SecurityModeConfigurable::NORMAL))
      assert_nil SignRiskEmitter.emit("test")
    ensure
      ENV.delete("RISK_ENFORCEMENT_DISABLED")
    end

    assert_nil SignRiskEnforcer.call(nil)
  end

  test "JitSecurityTurnstileVerifier response helper arms" do
    missing_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "1.2.3.4", secret_key: "secret")
    missing_secret = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", secret_key: "")

    assert_not missing_token["success"]
    assert_equal "missing cf-turnstile-response", missing_token["error"]
    assert_not missing_secret["success"]
    assert_equal "missing turnstile secret", missing_secret["error"]
  end

  test "ChainSeal verify rescue ArgumentError path via bad public key type" do
    assert_raises(ChainSeal::FormatError, ChainSeal::VerificationError) do
      ChainSeal.verify(payload: { a: 1 }, compact: "not-a-seal", public_key: "nope")
    end
  end
end
