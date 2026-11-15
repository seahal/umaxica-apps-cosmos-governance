# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_jwk"

module Jit
  module Security
    module Jwt
      class JwkTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::RSA.generate(3072)
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "exports public jwk without private material" do
          assert_equal "kid-1", @public_jwk.fetch("kid")
          assert_equal JitSecurityJwtJwk::ALGORITHM, @public_jwk.fetch("alg")
          assert_equal "sig", @public_jwk.fetch("use")
          assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & @public_jwk.keys
        end

        test "normalizes valid public jwk" do
          normalized = JitSecurityJwtJwk.normalize_public(@public_jwk.merge(extra: "ignored"))

          assert_equal @public_jwk, normalized
        end

        test "rejects public jwk with private material" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("d" => "secret"))
            end

          assert_match(/private JWK material/, error.message)
        end

        test "rejects unexpected algorithm" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("alg" => "ES384"))
            end

          assert_match(/alg must be PS256/, error.message)
        end

        test "rejects incomplete public jwk" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.except("n"))
            end

          assert_match(/missing n/, error.message)
        end

        test "imports valid public jwk material" do
          assert_kind_of OpenSSL::PKey::RSA, JitSecurityJwtJwk.import_public_key(@public_jwk)
          assert_equal 3072, JitSecurityJwtJwk.import_public_key(@public_jwk).n.num_bits
        end

        test "accepts RSA moduli at 3072 and 4096 bits and refuses 2048 bits" do
          {
            2_048 => false,
            3_072 => true,
            4_096 => true,
          }.each do |bits, accepted|
            key = OpenSSL::PKey::RSA.generate(bits)
            jwk = JWT::JWK.new(key, kid: "rsa-#{bits}").export.stringify_keys.except("d", "p", "q", "dp", "dq", "qi")
            jwk.merge!("alg" => "PS256", "use" => "sig")

            if accepted
              normalized = JitSecurityJwtJwk.normalize_public(jwk)

              assert_equal "RSA", normalized.fetch("kty")
              token = JWT.encode(
                { "modulus_bits" => bits }, key, "PS256", { "kid" => "rsa-#{bits}", "typ" => "JWT" },
              )

              payload, = JWT.decode(token, JitSecurityJwtJwk.import_public_key(normalized), true, algorithms: ["PS256"])

              assert_equal bits, payload.fetch("modulus_bits")
            else
              error = assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public(jwk) }

              assert_match(/at least 3072 bits/, error.message)
            end
          end
        end
      end
    end
  end
end
