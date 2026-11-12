# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtIssuerJwksAuthorityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  ISSUERS = {
    "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
    "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
  }.freeze

  test "Base Jump issuers sign RT and publish the matching public signing key" do
    JitSecurityJwtRegistry.reload!
    published_keys = {}

    ISSUERS.each do |namespace, host_env|
      origin = JumpRtSurface.issuer_origin(namespace)
      host = JumpRtSurface.normalize_host(ENV.fetch(host_env))
      token = JumpRtIssuer.call(namespace:, url: "https://#{host}/", dst: "internal")
      claims, header = JWT.decode(token, nil, false)

      assert_equal origin, claims.fetch("iss"), namespace
      assert_equal "ES384", header.fetch("alg"), namespace
      assert_equal "reuse", claims.fetch("rpl"), namespace
      host! host
      https!
      get "/.well-known/jwks.json"

      assert_response :ok
      published = response.parsed_body
      keys = published.fetch("keys")

      assert_includes 1..JitSecurityJwtRegistry::MAX_JUMP_PUBLISHED_JWKS_KEYS, keys.size, namespace
      assert_operator JSON.generate(published).bytesize,
                      :<=,
                      JitSecurityJwtRegistry::MAX_JUMP_PUBLISHED_JWKS_BYTES,
                      namespace
      assert_equal keys.size, keys.pluck("kid").uniq.size, namespace
      keys.each do |key|
        assert_equal "ES384", key.fetch("alg"), namespace
        assert_equal "sig", key.fetch("use"), namespace
        assert_equal "EC", key.fetch("kty"), namespace
        assert_equal "P-384", key.fetch("crv"), namespace
      end
      assert_includes keys.pluck("kid"), header.fetch("kid"), namespace
      assert_empty keys.flat_map(&:keys) & JitSecurityJwtJwk::PRIVATE_FIELDS, namespace
      published_keys[namespace] = keys
      verified, = JWT.decode(
        token, nil, true, algorithms: ["ES384"],
                          jwks: JWT::JWK::Set.new(published),
                          verify_iss: true, iss: origin,
                          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )

      assert_equal claims, verified, namespace
    end

    base_app_material = published_keys.fetch("BASE_APP").map { |key| key.slice("kty", "crv", "x", "y") }
    base_org_material = published_keys.fetch("BASE_ORG").map { |key| key.slice("kty", "crv", "x", "y") }

    assert_empty base_app_material & base_org_material, "Base app and org JWKS must not share public key material"
  end
end
