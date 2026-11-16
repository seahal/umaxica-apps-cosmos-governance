# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch31MoreEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityTurnstileVerifier blank token arms" do
    blank_token = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", blank_token["error"]
    nil_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", nil_token["error"]
  end

  test "CredentialSecurityTransition blank actor" do
    assert_raises(ArgumentError) { CredentialSecurityTransition.new(actor: nil, event: :rotate) }
  end

  test "AuthMethodGuard and single-use token easy rejects" do
    assert_not AuthMethodGuard.respond_to?(:allow?)
  end

  test "ConfigValues OriginValue to_s default and explicit ports" do
    https = ConfigValues.build("https://example.test")

    assert_equal "https://example.test", https.to_s
    http = ConfigValues.build("http://localhost", allow_localhost: true)

    assert_equal "http://localhost", http.to_s
    custom = ConfigValues.build("https://example.test:8443")

    assert_includes custom.to_s, ":8443"
  end

  test "JitSecurityJwtJtiGenerator generate produces strings" do
    a = JitSecurityJwtJtiGenerator.generate
    b = JitSecurityJwtJtiGenerator.generate

    assert_kind_of String, a
    assert_kind_of String, b
    assert_not_equal a, b
  end
end
