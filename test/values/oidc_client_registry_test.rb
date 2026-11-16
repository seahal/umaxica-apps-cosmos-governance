# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "find returns a first-party client config for a client account" do
    client = OidcClientRegistry.find("base-app-ww")

    assert_not_nil client
    assert_equal "base-app-ww", client.client_id
    assert_equal "base-app-ww", client.aud
    assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") }
    assert_not_predicate client, :public_client?
    assert_predicate client, :confidential_client?
    assert_predicate client, :private_key_jwt_client?
    assert_not_respond_to client, :client_secret
    assert_not_respond_to OidcClientRegistry, :authenticate
  end

  test "each first-party RP registers a callback on its own surface" do
    OidcRpSurfaceMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") },
             "#{client_id} has no registered canonical callback"
      assert_equal [client.resource_type], client.redirect_uris_by_realm.keys
    end
  end

  test "each first-party RP registers only the noun completion path" do
    OidcRpSurfaceMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)
      registered_paths = client.post_logout_redirect_uris.map { |uri| URI.parse(uri).path }.uniq

      assert_equal ["/sign/out/completion"], registered_paths, client_id
    end
  end

  test "find returns nil for unknown client" do
    client = OidcClientRegistry.find("unknown-client")

    assert_nil client
  end

  test "find! raises for unknown client" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown-client")
    end
  end

  test "client assertion authentication refuses an unknown client without returning claims" do
    result = OidcClientRegistry.verify_client_assertion(
      "unknown-client",
      "untrusted-assertion",
      token_url: "https://issuer.example.invalid/oauth/token",
    )

    assert_not_predicate result, :authenticated?
    assert_nil result.client
    assert_equal :none, result.step_up_claims_state
    assert_nil result.step_up_expectation
    assert_not_predicate result, :step_up_claims_present?
    assert_not OidcClientRegistry.authenticate_assertion(
      "unknown-client",
      "untrusted-assertion",
      token_url: "https://issuer.example.invalid/oauth/token",
    )
  end

  test "discovery audiences and revocation authentication methods stay within each realm" do
    client_audiences = OidcClientRegistry.audiences_for_resource_type("client")
    operator_audiences = OidcClientRegistry.audiences_for_resource_type("staff")

    assert_includes client_audiences, "base-app-ww"
    assert_not_includes client_audiences, "base-org-ww"
    assert_includes operator_audiences, "base-org-ww"
    assert_not_includes operator_audiences, "base-app-ww"
    assert_equal ["private_key_jwt"], OidcClientRegistry.revocation_endpoint_auth_methods_for("client")
    assert_equal ["private_key_jwt"], OidcClientRegistry.revocation_endpoint_auth_methods_for("operator")
    assert_raises(ArgumentError) { OidcClientRegistry.audiences_for_resource_type("unsupported") }
    assert_raises(ArgumentError) { OidcClientRegistry.revocation_endpoint_auth_methods_for("unsupported") }
  end

  private
end
