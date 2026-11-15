# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_local_keyset_installer"

module Jit
  module Security
    module Jwt
      class LocalKeysetInstallerTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @store_path = Rails.root.join("tmp/tests/local_jwt_keysets_#{SecureRandom.hex(8)}.json")
          @env_keys = local_jwt_env_keys
          @previous = @env_keys.index_with { |key| ENV[key] }
          @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          clear_local_jwt_env!
        end

        teardown do
          JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
          @previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
          FileUtils.rm_f(@store_path)
        end

        test "reinstalling from the same local store keeps app preference jwt signatures valid" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          token = PreferenceToken.encode(
            SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
            host: "log.umaxica.app",
            preference_type: "AppPreference",
            public_id: "pref-public",
            jti: "pref-jti",
            issued_at: Time.current,
          )

          assert_not_nil PreferenceToken.decode(token, host: "log.umaxica.app")

          clear_local_jwt_env!
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          decoded = PreferenceToken.decode(token, host: "log.umaxica.app")

          assert_not_nil decoded
          assert_equal "pref-public", decoded["sub"]
          assert_equal "pref-jti", decoded["jti"]
        end

        test "reinstalling from the same local store keeps org preference jwt signatures valid" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          token = PreferenceToken.encode(
            SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
            host: "log.umaxica.org",
            preference_type: "OrgPreference",
            public_id: "org-pref-public",
            jti: "org-pref-jti",
            issued_at: Time.current,
            jwt_issuer_id: "preference_org",
          )

          assert_not_nil PreferenceToken.decode(
            token,
            host: "log.umaxica.org",
            jwt_issuer_id: "preference_org",
          )

          clear_local_jwt_env!
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          decoded = PreferenceToken.decode(
            token,
            host: "log.umaxica.org",
            jwt_issuer_id: "preference_org",
          )

          assert_not_nil decoded
          assert_equal "org-pref-public", decoded["sub"]
          assert_equal "org-pref-jti", decoded["jti"]
        end

        test "partial keyset env is repaired from local store as one matching set" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          original_private_keyset = ENV.fetch("AUTH_JWT_PRIVATE_KEYSET")
          original_public_keyset = ENV.fetch("AUTH_JWT_PUBLIC_KEYSET")

          ENV["AUTH_JWT_PRIVATE_KEYSET"] = nil

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_keyset, ENV["AUTH_JWT_PRIVATE_KEYSET"]
          assert_equal original_public_keyset, ENV["AUTH_JWT_PUBLIC_KEYSET"]
        end

        test "install writes all local issuers to ignored tmp store" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))

          assert_equal %w(AUTH _algorithm _format).sort, store.keys.sort
          assert_equal "PS256", store.fetch("_algorithm")
          assert_equal JitSecurityJwtLocalKeysetInstaller::STORE_FORMAT, store.fetch("_format")
          assert_equal 0o600, File.stat(@store_path).mode & 0o777
        end

        test "install writes only public jwk material to local public keysets" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))
          keyset = JSON.parse(store.fetch("AUTH").fetch("public_keyset"))

          keyset.fetch("keys").each do |jwk|
            assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & jwk.keys
            assert_equal "PS256", jwk.fetch("alg")
            assert_equal "RSA", jwk.fetch("kty")
            assert_operator JWT::JWK.import(jwk).public_key.n.num_bits, :>=, 3_072
            assert_equal "sig", jwk.fetch("use")
          end
        end

        test "replaces an unversioned EC local key store with a PS256 RSA key store" do
          FileUtils.mkdir_p(File.dirname(@store_path))
          File.write(@store_path, JSON.generate("AUTH" => { "active_kid" => "old-ec-key" }))

          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end

          store = JSON.parse(File.read(@store_path))

          assert_equal "PS256", store.fetch("_algorithm")
          assert_equal "test-governance-ps256-a", store.fetch("AUTH").fetch("active_kid")
          assert_not_includes JSON.generate(store), "old-ec-key"
          assert(warnings.any? { |message| message.include?("jwt.local_keyset_store.contract_changed") })
          assert(warnings.any? { |message| message.include?("jwt.local_keyset.regenerated") })
        end

        test "malformed local store is regenerated into usable keys" do
          FileUtils.mkdir_p(File.dirname(@store_path))
          File.write(@store_path, "not-json")

          logged = []
          Rails.logger.stub(:warn, ->(message) { logged << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end
          JitSecurityJwtRegistry.reload!

          assert(logged.any? { |message| message.include?("jwt.local_keyset_store.malformed") })
          assert JitSecurityJwtRegistry.private_key_for("preference_app")
          assert JitSecurityJwtRegistry.public_key_for("preference_app", ENV.fetch("AUTH_JWT_ACTIVE_KID"))
        end

        test "generating fresh local keys warns that prior tokens will fail verification" do
          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end

          regenerated = warnings.select { |message| message.include?("jwt.local_keyset.regenerated") }

          assert_predicate regenerated, :present?,
                           "first install with no store should warn that local keys were minted"
          assert_equal 1, regenerated.length
          assert_includes regenerated.first, "GOVERNANCE"
          assert(regenerated.all? { |message| message.include?("will fail verification") })
        end

        test "reinstalling from an existing store does not warn about regeneration" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          clear_local_jwt_env!
          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end

          assert_empty warnings.select { |message| message.include?("jwt.local_keyset.regenerated") },
                       "reusing persisted keys must not look like a key rotation"
        end

        test "a restart reuses the one persisted repository keyset from the local store" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          kid = ENV.fetch("AUTH_JWT_ACTIVE_KID")
          private_keyset = ENV.fetch("AUTH_JWT_PRIVATE_KEYSET")
          clear_local_jwt_env!

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal kid, ENV.fetch("AUTH_JWT_ACTIVE_KID")
          assert_equal private_keyset, ENV.fetch("AUTH_JWT_PRIVATE_KEYSET")
          assert_equal "#{Rails.env}-governance-ps256-a", kid
        end

        test "installing twice in one process accepts the values the installer exported" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          kid = ENV.fetch("AUTH_JWT_ACTIVE_KID")

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal kid, ENV.fetch("AUTH_JWT_ACTIVE_KID")
        end

        test "explicit local jwt env values are not replaced" do
          ENV["AUTH_JWT_ACTIVE_KID"] = "explicit-governance-kid"
          ENV["AUTH_JWT_PRIVATE_KEYSET"] = '{"explicit-governance-kid":"private"}'
          ENV["AUTH_JWT_PUBLIC_KEYSET"] = '{"keys":[]}'

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal "explicit-governance-kid", ENV["AUTH_JWT_ACTIVE_KID"]
          assert_equal '{"explicit-governance-kid":"private"}', ENV["AUTH_JWT_PRIVATE_KEYSET"]
          assert_equal '{"keys":[]}', ENV["AUTH_JWT_PUBLIC_KEYSET"]
        end

        private

        def clear_local_jwt_env!
          @env_keys.each { |key| ENV.delete(key) }
        end

        def local_jwt_env_keys
          keys = %w(
            AUTH_JWT_ACTIVE_KID AUTH_JWT_PRIVATE_KEYSET AUTH_JWT_PUBLIC_KEYSET
            PREFERENCE_APP_JWT_ACTIVE_KID PREFERENCE_APP_JWT_PRIVATE_KEYSET PREFERENCE_APP_JWT_PUBLIC_KEYSET
            PREFERENCE_COM_JWT_ACTIVE_KID PREFERENCE_COM_JWT_PRIVATE_KEYSET PREFERENCE_COM_JWT_PUBLIC_KEYSET
            PREFERENCE_ORG_JWT_ACTIVE_KID PREFERENCE_ORG_JWT_PRIVATE_KEYSET PREFERENCE_ORG_JWT_PUBLIC_KEYSET
          )
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            keys << "JWT_#{namespace}_ACTIVE_KID"
            keys << "JWT_#{namespace}_PRIVATE_KEY"
            keys << "JWT_#{namespace}_PUBLIC_KEYSET"
          end
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            keys << "OIDC_CLIENT_#{namespace}_ACTIVE_KID"
            keys << "OIDC_CLIENT_#{namespace}_PRIVATE_KEY"
            keys << "OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET"
          end
          keys
        end
      end
    end
  end
end
