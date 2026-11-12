# typed: false
# frozen_string_literal: true

# The explicit allowlist of fully qualified domain names this Rails application serves, and the
# availability slot each one belongs to.
#
# The kill switch in `FqdnAvailabilityGate` selects a Flipper feature from the *slot*, never from the
# `Host` header. A header that does not appear here resolves to nil and the gate fails closed, so an
# attacker cannot invent a feature name -- or reach a surface -- by sending an arbitrary `Host`.
#
# The hostname lists mirror the `constraints(host:)` declarations in `config/routes/*.rb` exactly:
# same boot-config slots, same environment variables, same literal development aliases.
# `Security::Invariants::FqdnAvailabilityRegistryInvariantTest` fails when the two drift apart.
#
# Note on naming: `ConfigValues::HostFamilyValues` also carries an `acme_*` family whose values are
# the `base.*.localhost` development aliases already listed under the `base_*` slots here. There is
# no separate `acme_*` slot because no route constrains on one.
module FqdnAvailabilityRegistry
  Slot = Data.define(:name, :hostnames)

  # Slot name => the hostnames that reach it. Values are resolved once per boot, because
  # `config/routes/*.rb` resolves the same sources once per boot when the routes are drawn.
  SLOT_SOURCES = {
    base_service: ->(hosts) { [hosts.base_service.host, ENV["PUBLIC_BASE_SERVICE_URL"], "base.app.localhost"] },
    base_corporate: ->(hosts) { [hosts.base_corporate.host, ENV["PUBLIC_BASE_CORPORATE_URL"], "base.com.localhost"] },
    base_staff: ->(hosts) { [hosts.base_staff.host, ENV["PUBLIC_BASE_STAFF_URL"], "base.org.localhost"] },
    tech_staff: ->(hosts) { [hosts.tech_staff.host, ENV["PRIVATE_TECH_STAFF_URL"], "tech.org.localhost"] },
    mission: lambda { |_hosts|
      ["mission-governance.umaxica.dev"]
    },
    flipper: lambda { |_hosts|
      ["flipper-governance.umaxica.dev"]
    },
    blazer: lambda { |_hosts|
      ["blazer-governance.umaxica.dev"]
    },
    pghero: lambda { |_hosts|
      ["pghero-governance.umaxica.dev"]
    },
    coverband: lambda { |_hosts|
      ["coverband-governance.umaxica.dev"]
    },
    swagger: lambda { |_hosts|
      ["swagger-governance.umaxica.dev"]
    },
  }.freeze

  SLOT_NAMES = SLOT_SOURCES.keys.freeze

  FLAG_PREFIX = "fqdn_available_"
  module_function

  def flag_name_for(slot) = :"#{FLAG_PREFIX}#{slot}"

  def flag_names = SLOT_NAMES.map { |slot| flag_name_for(slot) }

  # @return [Symbol, nil] the slot the hostname belongs to, or nil when the hostname is not served.
  def slot_for(hostname)
    return nil if hostname.blank?

    index.fetch(normalize(hostname), nil)
  end

  def slots
    @slots ||= SLOT_SOURCES.map do |name, source|
      Slot.new(name: name, hostnames: hostnames_from(source))
    end.freeze
  end

  # hostname => slot. Built once per boot and frozen.
  def index
    @index ||= slots.each_with_object({}) do |slot, map|
      slot.hostnames.each do |hostname|
        claimed = map[hostname]

        if claimed && claimed != slot.name
          raise ArgumentError,
                "FQDN #{hostname} is claimed by both #{claimed} and #{slot.name}; " \
                "one hostname cannot have two availability switches"
        end

        map[hostname] = slot.name
      end
    end.freeze
  end

  def hostnames_from(source)
    hostnames =
      source.call(Rails.configuration.x.boot_config.fetch(:hosts)).compact_blank.map do |value|
        normalize(value)
      end
    hostnames.uniq!
    hostnames.freeze
  end

  def normalize(value) = value.to_s.strip.downcase
  private_class_method :hostnames_from
end
