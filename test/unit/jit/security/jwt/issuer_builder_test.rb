# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_issuer_builder"

module Jit
  module Security
    module Jwt
      class IssuerBuilderTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @active_key = OpenSSL::PKey::RSA.generate(3072)
          @legacy_key = OpenSSL::PKey::RSA.generate(3072)
        end

        test "builds keyset issuer with active private key and grace public key" do
          record = JitSecurityJwtIssuerBuilder.build_keyset_issuer(
            id: "auth",
            private_keyset: JSON.generate("active-kid" => base64_der(@active_key)),
            private_keyset_source: "AUTH_JWT_PRIVATE_KEYSET",
            public_keyset: JSON.generate(keys: [JitSecurityJwtJwk.export_public(@legacy_key, kid: "legacy-kid")]),
            public_keyset_source: "AUTH_JWT_PUBLIC_KEYSET",
            active_kid: "active-kid",
            issuer: "issuer",
            audiences: ["audience"],
            revoked_kids: [],
          )

          assert_equal "active-kid", record.current_kid
          assert_equal "auth", record.id
          assert_not_nil record.keys.fetch("active-kid").private_key
          assert_nil record.keys.fetch("legacy-kid").private_key
          assert_not_nil record.public_key_for("legacy-kid")
          assert_includes record.jwks.fetch(:keys).map { |jwk| jwk.fetch("kid") }, "legacy-kid"
        end

        test "marks revoked public keys as unpublished and unverifiable" do
          record = JitSecurityJwtIssuerBuilder.build_keyset_issuer(
            id: "auth",
            private_keyset: JSON.generate("active-kid" => base64_der(@active_key)),
            private_keyset_source: "AUTH_JWT_PRIVATE_KEYSET",
            public_keyset: JSON.generate(keys: [JitSecurityJwtJwk.export_public(@legacy_key, kid: "legacy-kid")]),
            public_keyset_source: "AUTH_JWT_PUBLIC_KEYSET",
            active_kid: "active-kid",
            issuer: "issuer",
            audiences: ["audience"],
            revoked_kids: ["legacy-kid"],
          )

          assert_nil record.public_key_for("legacy-kid")
          assert_not_includes record.jwks.fetch(:keys).map { |jwk| jwk.fetch("kid") }, "legacy-kid"
        end

        private

        def base64_der(key)
          Base64.strict_encode64(key.private_to_der)
        end
      end
    end
  end
end
