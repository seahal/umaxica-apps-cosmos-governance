# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_registry"

module Jit
  module Security
    module Jwt
      class RegistryTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          @auth_key = OpenSSL::PKey::RSA.generate(3072)
          @auth_legacy_key = OpenSSL::PKey::RSA.generate(3072)
        end

        teardown do
          JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
        end

        test "loads configured keys once into immutable issuer records" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!

            assert_equal "auth-kid", issuers.fetch("auth").current_kid
            assert_equal %w(umaxica-api-client umaxica-api-operator),
                         issuers.fetch("auth").audiences
            assert_equal "auth-kid", issuers.fetch("preference_app").current_kid
            assert_equal ["app"], issuers.fetch("preference_app").audiences
            assert_equal "auth-kid", issuers.fetch("preference_org").current_kid
            assert_equal ["org"], issuers.fetch("preference_org").audiences
            assert_equal "auth-kid", issuers.fetch("preference_com").current_kid
            assert_equal ["com"], issuers.fetch("preference_com").audiences
            assert_equal "auth-kid", issuers.fetch("surface:BASE_APP").current_kid
            assert_predicate issuers.fetch("surface:BASE_APP").jwks.fetch(:keys), :present?
            assert_equal JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.size,
                         issuers.keys.grep(/\Aoidc_client:/).size
            assert JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference_app", "auth-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference_org", "auth-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference_com", "auth-legacy-kid")
          end
        end

        test "all first-party issuers publish and use the one repository signing keyset" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!
            shared = issuers.fetch("auth")

            issuers.each_value do |issuer|
              assert_equal shared.current_kid, issuer.current_kid, issuer.id
              assert_equal shared.jwks, issuer.jwks, issuer.id
              assert_equal(
                shared.keys.transform_values { |key| key.public_key.public_to_der },
                issuer.keys.transform_values { |key| key.public_key.public_to_der },
                issuer.id,
              )
            end
          end
        end

        test "the repository signing keyset is required by every first-party issuer" do
          with_registry_inputs("AUTH_JWT_PRIVATE_KEYSET" => nil) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_equal "AUTH_JWT_PRIVATE_KEYSET is required", error.message
          end
        end

        test "OIDC client assertion issuer shares the repository signing keyset" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!
            issuer = issuers.fetch("oidc_client:BASE_RP_APP_WW")

            assert_equal "auth-kid", issuer.current_kid
            assert_equal "oidc_client:base_rp_app_ww", issuer.issuer
            assert_equal issuers.fetch("auth").jwks, issuer.jwks
          end
        end

        test "namespace-less jwks includes auth active and grace public keys" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            kids = JitSecurityJwtJwksService.jwk_set.fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_includes kids, "auth-kid"
            assert_includes kids, "auth-legacy-kid"
          end
        end

        test "jwks service does not expose an uncalled standalone JWK normalizer" do
          assert_not_respond_to JitSecurityJwtJwksService, :normalized_public_jwk
        end

        test "grace public key verifies old tokens without retaining old private key" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            token = JWT.encode(
              {
                "iss" => "issuer",
                "aud" => "audience",
                "sub" => "subject",
                "exp" => 5.minutes.from_now.to_i,
                "iat" => Time.current.to_i,
              },
              @auth_legacy_key,
              JitSecurityJwtRegistry::ALGORITHM,
              { kid: "auth-legacy-kid", typ: "auth-access-token;client" },
            )

            public_key = JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")

            assert_nil JitSecurityJwtRegistry.private_key_for("auth", "auth-legacy-kid")
            assert_not_nil public_key
            assert_nothing_raised do
              JWT.decode(token, public_key, true, algorithms: [JitSecurityJwtRegistry::ALGORITHM])
            end
          end
        end

        test "jwks never exposes private key material" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            JitSecurityJwtRegistry.jwks_for("auth").fetch(:keys).each do |jwk|
              assert_empty JitSecurityJwtRegistry::PRIVATE_JWK_FIELDS & jwk.keys
              assert_equal JitSecurityJwtRegistry::ALGORITHM, jwk.fetch("alg")
              assert_equal "sig", jwk.fetch("use")
              assert_equal "RSA", jwk.fetch("kty")
              assert_operator JWT::JWK.import(jwk).public_key.n.num_bits, :>=, 3_072
              assert_not_includes jwk.keys, "crv"
            end
          end
        end

        test "rejects malformed public jwk json at registry load" do
          with_registry_inputs("AUTH_JWT_PUBLIC_KEYSET" => "not-json") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/AUTH_JWT_PUBLIC_KEYSET contains invalid JSON/, error.message)
          end
        end

        test "rejects current public jwk that does not match current private key" do
          wrong_key = OpenSSL::PKey::RSA.generate(3072)
          wrong_jwk = JitSecurityJwtRegistry.export_public_jwk(wrong_key, kid: "auth-kid")

          with_registry_inputs("AUTH_JWT_PUBLIC_KEYSET" => JSON.generate([wrong_jwk])) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active\/private key "auth-kid" does not match configured public JWK/, error.message)
          end
        end

        test "does not expose revoked kids in jwks and refuses their public keys" do
          with_registry_inputs("AUTH_JWT_REVOKED_KIDS" => "auth-legacy-kid") do
            JitSecurityJwtRegistry.reload!

            assert_nil JitSecurityJwtRegistry.public_key_for("surface:BASE_APP", "auth-legacy-kid")
            kids = JitSecurityJwtRegistry.jwks_for("surface:BASE_APP").fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_not_includes kids, "auth-legacy-kid"
          end
        end

        test "rejects default active kid unless explicitly allowed" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => nil,
          ) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active kid must not be "default"/, error.message)
          end
        end

        test "rejects reserved environment kid markers outside local environments" do
          Rails.env.stub(:local?, false) do
            with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-ps256-a") do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/reserved environment markers/, error.message)
            end
          end
        end

        test "allows reserved environment kid markers in local environments" do
          with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-ps256-a") do
            assert_nothing_raised { JitSecurityJwtRegistry.reload! }
          end
        end

        test "rejects unknown issuer and namespace identifiers" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            unknown_issuer =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.issuer("missing")
              end
            assert_match(/unknown JWT issuer registry id/, unknown_issuer.message)

            unsupported_surface =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.surface("missing")
              end
            assert_match(/unsupported JWT issuer namespace/, unsupported_surface.message)

            unsupported_client =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.oidc_client("missing")
              end
            assert_match(/unsupported OIDC client JWT namespace/, unsupported_client.message)
          end
        end

        test "does not allow insecure default kid outside local environments" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => "1",
          ) do
            Rails.env.stub(:local?, false) do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/active kid must not be "default"/, error.message)
            end
          end
        end

        test "rejects non-empty records without issuer" do
          record = issuer_record(issuer: nil)

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth issuer is missing/, error.message)
        end

        test "rejects non-empty records without audiences" do
          record = issuer_record(audiences: [])

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth audiences are missing/, error.message)
        end

        test "allows empty optional surface records without issuer or audiences" do
          record = JitSecurityJwtIssuerRecord.new(
            id: "surface:BASE_APP",
            namespace: "BASE_APP",
            issuer: nil,
            audiences: [],
            current_kid: nil,
            keys: {},
            revoked_kids: Set.new,
          )

          assert_nothing_raised { JitSecurityJwtRegistry.validate_record!(record) }
        end

        test "rejects records whose active key is not published in jwks" do
          record = issuer_record(
            key_state: "retired",
          )

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/active key "auth-kid" is missing from JWKS/, error.message)
        end

        test "every Jump issuer record carries the PUBLIC_* issuer origin that Jump RTs sign as" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!

            JumpRtSurface::ISSUER_NAMESPACES.each do |namespace|
              assert_equal JumpRtSurface.issuer_origin(namespace), issuers.fetch("surface:#{namespace}").issuer,
                           namespace
            end
          end
        end

        test "an unsafe Jump issuer origin fails registry configuration at boot instead of at request time" do
          with_registry_inputs("PUBLIC_BASE_SERVICE_URL" => "base.app.localhost") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/PUBLIC_BASE_SERVICE_URL/, error.message)
          end
        end

        test "a missing Jump issuer origin fails registry configuration" do
          with_registry_inputs("PUBLIC_BASE_STAFF_URL" => nil) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/PUBLIC_BASE_STAFF_URL is required/, error.message)
          end
        end

        test "does not retain invalid registry after failed reload" do
          with_registry_inputs do
            valid_records = JitSecurityJwtRegistry.reload!

            with_env("AUTH_JWT_PUBLIC_KEYSET" => "not-json") do
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }
            end

            assert_same valid_records, JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          end
        end

        private

        def issuer_record(issuer: "issuer", audiences: ["audience"], key_state: "active")
          JitSecurityJwtIssuerRecord.new(
            id: "auth",
            namespace: "AUTH",
            issuer: issuer,
            audiences: audiences,
            current_kid: "auth-kid",
            keys: {
              "auth-kid" => KeyRecord.new(
                kid: "auth-kid",
                private_key: @auth_key,
                public_key: @auth_key,
                public_jwk: JitSecurityJwtRegistry.export_public_jwk(@auth_key, kid: "auth-kid"),
                state: key_state,
              ),
            },
            revoked_kids: Set.new,
          )
        end

        def with_registry_inputs(extra_env = {})
          env = registry_input_env(extra_env)
          creds = registry_input_creds(env)
          with_env(env) do
            Rails.app.creds.stub(:option, ->(key, default: nil) { creds.fetch(key, default) }) do
              yield
            end
          end
        end

        def registry_input_env(extra_env)
          env = {
            "AUTH_JWT_ACTIVE_KID" => "auth-kid",
            "AUTH_JWT_ISSUER" => "auth-test-issuer",
            "PREFERENCE_COM_JWT_ISSUER" => "https://www.umaxica.com",
            "PREFERENCE_COM_JWT_AUDIENCE" => "com",
          }.merge(extra_env)
          env["AUTH_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key))
          env["AUTH_JWT_PUBLIC_KEYSET"] =
            JSON.generate(keys: [JitSecurityJwtRegistry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")])
          env.merge!(extra_env)
          env
        end

        def registry_input_creds(env)
          {
            AUTH_JWT_PRIVATE_KEYSET: env["AUTH_JWT_PRIVATE_KEYSET"],
            AUTH_JWT_PUBLIC_KEYSET: env["AUTH_JWT_PUBLIC_KEYSET"],
          }
        end

        def with_env(values)
          previous = {}
          values.each do |key, value|
            previous[key] = ENV[key]
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
          yield
        ensure
          previous.each do |key, value|
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
        end

        def base64_der(key)
          Base64.strict_encode64(key.private_to_der)
        end
      end
    end
  end
end
