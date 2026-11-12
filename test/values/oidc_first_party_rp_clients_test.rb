# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcFirstPartyRpClientsTest < ActiveSupport::TestCase
  setup do
    OidcClientRegistry::CLIENTS_CACHE.set(nil)
  end

  test "registers first-party RPs with unique ids keys and callback paths" do
    OidcRpSurfaceMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_equal client_id, client.client_id
      assert_equal client_id, client.aud
      assert_predicate client, :private_key_jwt_client?
      assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") },
             "#{client_id} missing /oidc/callback"
      assert client.post_logout_redirect_uris.any? { |uri| URI.parse(uri).path == "/sign/out/completion" },
             "#{client_id} missing /sign/out/completion"
      assert_predicate(
        JitSecurityJwtRegistry.private_key_for("oidc_client:#{client.jwt_namespace}"),
        :present?,
        "#{client_id} missing private key for #{client.jwt_namespace}",
      )
    end

    namespaces =
      OidcRpSurfaceMap.first_party_rp_client_ids.map do |client_id|
        OidcClientRegistry.find!(client_id).jwt_namespace
      end

    assert_equal 3, namespaces.uniq.size
    assert_equal(
      %w(BASE_RP_APP_WW BASE_RP_ORG_WW TECH_ORG_WW),
      namespaces,
    )
    assert_equal 3, OidcRpSurfaceMap.first_party_rp_client_ids.size
    assert_predicate OidcRpSurfaceMap, :unique_client_ids?
  end
end
