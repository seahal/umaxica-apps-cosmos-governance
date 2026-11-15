# typed: false
# frozen_string_literal: true

module Webauthn
  # Closed mapping from app/org owners to their credential store and actor
  # model. Credentials never cross owners; ceremony configuration is owned by
  # Access. Surface resolution is explicit, never inferred from hosts.
  class Surface
    class UnknownSurfaceError < StandardError; end

    attr_reader :passkey_class_name, :passkey_status_class_name, :actor_foreign_key

    def initialize(passkey_class_name:, passkey_status_class_name:, actor_foreign_key:)
      @passkey_class_name = passkey_class_name
      @passkey_status_class_name = passkey_status_class_name
      @actor_foreign_key = actor_foreign_key
      freeze
    end

    public
    def passkey_class = passkey_class_name.constantize

    def passkey_status_class = passkey_status_class_name.constantize

    REGISTRY = {
      app: new(
        passkey_class_name: "ClientPasskey",
        passkey_status_class_name: "ClientPasskeyStatus",
        actor_foreign_key: "user_id",
      ),
      org: new(
        passkey_class_name: "OperatorPasskey",
        passkey_status_class_name: "OperatorPasskeyStatus",
        actor_foreign_key: "staff_id",
      ),
    }.freeze

    def self.for(value)
      return value if value.is_a?(Surface)

      REGISTRY.fetch(value.to_sym) do
        raise UnknownSurfaceError,
              "Unknown WebAuthn surface: #{value.inspect} (expected one of #{REGISTRY.keys.inspect})"
      end
    end
    public_class_method :for

    def self.all = REGISTRY.values
    public_class_method :all
  end
end
