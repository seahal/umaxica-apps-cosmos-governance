# typed: false
# frozen_string_literal: true

module Webauthn
  # Closed enumeration of the WebAuthn surfaces. Each surface owns its own
  # relying party, credential store, and actor model; credentials never cross
  # surfaces. Surface resolution is always an explicit declaration
  # never inferred from class names or hosts.
  class Surface
    class UnknownSurfaceError < StandardError; end

    attr_reader :key, :env_prefix, :passkey_class_name, :passkey_status_class_name,
                :actor_foreign_key, :actor_association_name,
                :account_label

    def initialize(key, env_prefix:, passkey_class_name:, passkey_status_class_name:,
                   actor_foreign_key:, actor_association_name:,
                   account_label:)
      @key = key
      @env_prefix = env_prefix
      @passkey_class_name = passkey_class_name
      @passkey_status_class_name = passkey_status_class_name
      @actor_foreign_key = actor_foreign_key
      @actor_association_name = actor_association_name
      # adr/passkey-authenticator-account-label.md: the authenticator stores this fixed,
      # non-identifying label as user.name and user.displayName; it never selects an Identity.
      @account_label = account_label
      freeze
    end

    def passkey_class = passkey_class_name.constantize

    def passkey_status_class = passkey_status_class_name.constantize

    delegate :to_s, to: :key

    REGISTRY = {
      app: new(
        :app,
        env_prefix: "APP",
        passkey_class_name: "ClientPasskey",
        passkey_status_class_name: "ClientPasskeyStatus",
        actor_foreign_key: "user_id",
        actor_association_name: :user,
        account_label: "umaxica.app",
      ),
      org: new(
        :org,
        env_prefix: "ORG",
        passkey_class_name: "OperatorPasskey",
        passkey_status_class_name: "OperatorPasskeyStatus",
        actor_foreign_key: "staff_id",
        actor_association_name: :staff,
        account_label: "umaxica.org",
      ),
    }.freeze

    def self.for(key)
      return key if key.is_a?(Surface)

      REGISTRY.fetch(key.to_sym) do
        raise UnknownSurfaceError, "Unknown WebAuthn surface: #{key.inspect} (expected one of #{REGISTRY.keys.inspect})"
      end
    end

    def self.all = REGISTRY.values
  end
end
