# typed: false
# frozen_string_literal: true

require "test_helper"

class JitSecurityTurnstileOutageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an unreachable challenge provider is reported as an outage rather than raised" do
    verifier = JitSecurityTurnstileVerifier.new(token: "token", remote_ip: "127.0.0.1", secret_key: "secret")
    verifier.define_singleton_method(:perform_request) { raise Errno::ECONNREFUSED, "provider unreachable" }

    result = verifier.verify

    assert_not result["success"]
    assert result["unavailable"], "the caller has to tell an outage apart from a failed challenge"
  end

  test "a missing token or secret is a failure rather than a silent pass" do
    no_token = JitSecurityTurnstileVerifier.new(token: "", remote_ip: "127.0.0.1", secret_key: "secret")

    assert_not no_token.verify["success"]

    no_secret = JitSecurityTurnstileVerifier.new(token: "token", remote_ip: "127.0.0.1", secret_key: "")

    assert_not no_secret.verify["success"]
  end
end
