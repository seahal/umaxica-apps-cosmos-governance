# frozen_string_literal: true

module ConfigValues
  HostFamilyValues =
    Data.define(
      :base_service,
      :base_corporate,
      :base_staff,
      :visa_service,
      :visa_staff,
      :tech_staff,
      :auth_service,
      :auth_staff,
    ) do
      def base_origins
        [base_service, base_corporate, base_staff]
      end

      def base_for_resource_type(resource_type)
        case resource_type.to_s
        when "client" then base_service
        when "operator", "staff" then base_staff
        else raise ArgumentError, "unsupported Base authority resource type"
        end
      end
    end
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  public
  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(**host_family_origins(env: env, production: production)).freeze
  end

  def host_family_origins(env:, production:)
    host_family_primary_origins(env: env, production: production).merge(
      host_family_secondary_origins(env: env, production: production),
    )
  end

  def host_family_primary_origins(env:, production:)
    {
      base_service: origin(env, base_key(env, "SERVICE"), production: production),
      base_corporate: origin(env, base_key(env, "CORPORATE"), production: production),
      base_staff: origin(env, base_key(env, "STAFF"), production: production),
    }
  end

  def host_family_secondary_origins(env:, production:)
    {
      visa_service: required_origin(env, visa_key(env, "SERVICE"), production: production),
      visa_staff: required_origin(env, visa_key(env, "STAFF"), production: production),
      tech_staff: required_origin(env, "PUBLIC_TECH_STAFF_URL", production: production),
      # Base never links to Auth, but the OP sends the browser there after POST /sign, and
      # form-action follows that redirect chain (see the content security policy initializer).
      auth_service: required_origin(env, "PUBLIC_AUTH_SERVICE_URL", production: production),
      auth_staff: required_origin(env, "PUBLIC_AUTH_STAFF_URL", production: production),
    }
  end

  def visa_key(env, surface)
    private_key = "VISA_#{surface}_URL"
    public_key = "PUBLIC_VISA_#{surface}_URL"
    return private_key if env.key?(private_key)
    return public_key if env.key?(public_key)

    raise KeyError, "Missing required ENV key: #{private_key} or #{public_key}"
  end

  # Resolves the ENV key for a base surface (service/corporate/staff).
  def base_key(env, surface)
    if env.key?("BASE_#{surface}_URL")
      "BASE_#{surface}_URL"
    else
      "PUBLIC_BASE_#{surface}_URL"
    end
  end

  def origin(env, key, production:)
    raw = env.fetch(key)
    allow_localhost = !production
    uri = raw.to_s.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end

  # Tech's host is required in every environment.
  def required_origin(env, key, production:)
    raw = env.fetch(key)
    allow_localhost = !production
    uri = raw.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end

  private :host_family_origins, :host_family_primary_origins, :host_family_secondary_origins,
          :required_origin, :visa_key
end
