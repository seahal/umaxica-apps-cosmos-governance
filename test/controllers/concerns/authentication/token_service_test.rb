# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationTokenServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "decode returns nil for blank token" do
    result = AuthenticationTokenService.decode("", host: "example.com", resource_type: "client")

    assert_nil result
  end

  test "decode returns nil for blank host" do
    result = AuthenticationTokenService.decode("some_token", host: "", resource_type: "client")

    assert_nil result
  end

  test "extract_subject returns subject from payload" do
    payload = { "sub" => 123 }

    assert_equal 123, AuthenticationTokenService.extract_subject(payload)
  end

  test "extract_resource_type returns act from payload" do
    payload = { "scope" => "authenticated domain:operator read:org" }

    assert_equal "operator", AuthenticationTokenService.extract_resource_type(payload)
  end

  test "extract_session_id returns sid from payload" do
    payload = { "sid" => "abc123" }

    assert_equal "abc123", AuthenticationTokenService.extract_session_id(payload)
  end

  test "extract_jti returns jti from payload" do
    payload = { "jti" => "xyz789" }

    assert_equal "xyz789", AuthenticationTokenService.extract_jti(payload)
  end

  test "resource_type_scope_matches? returns true for matching user" do
    payload = { "scope" => "authenticated domain:client" }

    assert AuthenticationTokenService.resource_type_scope_matches?(payload, "client")
  end

  test "resource_type_scope_matches? returns false for mismatched actor" do
    payload = { "scope" => "authenticated domain:client" }

    assert_not AuthenticationTokenService.resource_type_scope_matches?(payload, "operator")
  end

  test "resource_type_scope_matches? rejects blank and unknown actor claims" do
    assert_not AuthenticationTokenService.resource_type_scope_matches?(nil, "client")
    assert_not AuthenticationTokenService.resource_type_scope_matches?({}, "client")
    assert_not AuthenticationTokenService.resource_type_scope_matches?({ "scope" => "domain:bad" }, "client")
  end

  test "decode accepts an externally signed client token without preference authority" do
    payload = {
      "iss" => AuthenticationJwtConfiguration.issuer,
      "aud" => AuthenticationJwtConfiguration.audiences("client"),
      "sub" => "external-client-subject",
      "client_id" => AuthenticationJwtConfiguration.client_id("client"),
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 10.minutes.from_now.to_i,
      "jti" => "external-token-id",
      "sid" => "external-session-id",
      "acr" => "aal1",
      "scope" => "authenticated domain:client read:self write:self",
    }
    token = JWT.encode(
      payload, AuthenticationJwtConfiguration.private_key, "ES384",
      { "typ" => "at+jwt", "kid" => JitSecurityJwtKeyring.active_kid },
    )

    assert_predicate token, :present?

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client")

    assert_predicate payload, :present?
    assert_equal "external-client-subject", payload["sub"]
    assert_nil payload["prf"], "auth access tokens must not carry preference snapshots"
  end

  test "decode rejects token when resource_type issuer/type do not match" do
    clients(:one)
    payload = {
      "iss" => AuthenticationJwtConfiguration.issuer,
      "aud" => AuthenticationJwtConfiguration.audiences("client"),
      "sub" => "external-client-subject",
      "client_id" => AuthenticationJwtConfiguration.client_id("client"),
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 10.minutes.from_now.to_i,
      "jti" => "external-token-id",
      "sid" => "external-session-id",
      "acr" => "aal1",
      "scope" => "authenticated domain:client read:self write:self",
    }
    token = JWT.encode(
      payload, AuthenticationJwtConfiguration.private_key, "ES384",
      { "typ" => "at+jwt", "kid" => JitSecurityJwtKeyring.active_kid },
    )

    assert_predicate AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client"), :present?
    assert_nil AuthenticationTokenService.decode(token, host: "example.com", resource_type: "operator")
  end

  test "extract type scopes and scope membership" do
    payload = { "scope" => "domain:client profile email" }

    assert_equal "client", AuthenticationTokenService.extract_resource_type(payload)
    assert_equal %w(domain:client profile email), AuthenticationTokenService.extract_scopes(payload)
    assert AuthenticationTokenService.has_scope?(payload, :profile)
    assert_not AuthenticationTokenService.has_scope?(payload, :admin)
  end
end
