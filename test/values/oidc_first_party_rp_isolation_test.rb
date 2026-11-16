# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcFirstPartyRpIsolationTest < ActiveSupport::TestCase
  test "first-party browser RPs have isolated clients audiences namespaces and redirects" do
    ids = OidcRpSurfaceMap.first_party_rp_client_ids
    clients = ids.map { |client_id| OidcClientRegistry.find!(client_id) }

    assert_equal 3, clients.size
    assert_equal ids, clients.map(&:client_id)
    assert_equal ids.size, clients.map(&:aud).uniq.size
    assert_equal ids.size, clients.map(&:jwt_namespace).uniq.size
    assert_equal ids.size, clients.map { |client| client.redirect_uris.sort }.uniq.size
    clients.each do |client|
      assert_predicate client, :private_key_jwt_client?
      assert_includes %w(client operator), client.resource_type
      assert_predicate client.redirect_uris, :present?
    end

    base_app = OidcClientRegistry.find!("base-app-ww")
    base_org = OidcClientRegistry.find!("base-org-ww")

    assert_equal "client", base_app.resource_type
    assert_equal "operator", base_org.resource_type
    assert_not_equal base_app.redirect_uris, base_org.redirect_uris
    assert_not_equal base_app.jwt_namespace, base_org.jwt_namespace

    tech = OidcClientRegistry.find!("tech-org-ww")

    assert_equal "operator", tech.resource_type
    assert_equal "tech-org-ww", tech.aud
    assert_equal OperatorCapabilityGrant::TECH_ACCESS, tech.required_operator_capability
    assert_not_equal base_org.redirect_uris, tech.redirect_uris
    assert_not_equal base_org.jwt_namespace, tech.jwt_namespace
  end
end
