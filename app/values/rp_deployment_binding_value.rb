# typed: false
# frozen_string_literal: true

# Trusted deployment binding for Browser RP client identifiers (one.md section 5.1, R4-WU01/02A).
#
# Client IDs remain available to the retained models while only the Base and Tech RPs are active.
#
# The region comes only from the process environment set by the trusted launcher
# (`UMAXICA_DEPLOYMENT_REGION`). It is never read from a Host, an `ri` parameter, a token claim or
# any other request input, and there is no default: a process without it refuses to resolve a
# regional client rather than silently becoming JP.
class RpDeploymentBindingValue
  WORLDWIDE = "ww"

  # Canonical Core bridge records retain their metadata; this does not register a local Core RP store.
  REGIONAL_RPS = %w(core-app core-org).freeze
  WORLDWIDE_RPS = %w(base-app base-org tech-org).freeze
  ACTIVE_RPS = %w(base-app base-org tech-org).freeze

  REGIONS = %w(jp us).freeze

  class UnknownRegion < ArgumentError; end

  class UnknownRp < KeyError; end

  class << self
    public

    # The exact Client ID this deployment uses for a retained RP family/realm.
    def client_id(family_realm)
      key = family_realm.to_s
      return "#{key}-#{WORLDWIDE}" if WORLDWIDE_RPS.include?(key)
      return "#{key}-#{region}" if REGIONAL_RPS.include?(key)

      raise UnknownRp, "unknown RP family/realm: #{family_realm.inspect}"
    end

    def active_client_ids = ACTIVE_RPS.map { |key| client_id(key) }

    def region
      value = ENV.fetch("UMAXICA_DEPLOYMENT_REGION")
      raise UnknownRegion, "unknown deployment region: #{value.inspect}" unless REGIONS.include?(value)

      value
    end
  end
end
