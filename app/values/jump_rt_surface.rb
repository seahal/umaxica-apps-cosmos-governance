# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  # Base app and org origins are the only local Jump issuer boundaries.
  ISSUER_ORIGIN_ENV = {
    "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
    "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
  }.freeze
  ISSUER_NAMESPACES = ISSUER_ORIGIN_ENV.keys.freeze

  JWKS_PATH = "/.well-known/jwks.json"

  # The issuer origin is also the Jump return origin for the namespace. Rails.env plays no part: the
  # identity is whatever PUBLIC_* origin publishes this instance's active signing key in its JWKS.
  def issuer_origin(namespace, env: ENV)
    normalized_namespace = normalize_namespace(namespace)
    name = ISSUER_ORIGIN_ENV.fetch(normalized_namespace)
    raw = env[name]
    raise JumpRtConfigurationError, "#{name} is required for Jump issuance" if raw.blank?

    raw = raw.to_s
    candidate = raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? raw : "https://#{raw}"
    begin
      ConfigValues.public_https_origin(candidate)
    rescue ArgumentError => e
      raise JumpRtConfigurationError, "#{name} must be a public HTTPS origin for Jump: #{e.message}"
    end
  end

  def issuer_jwks_uri(namespace, env: ENV)
    "#{issuer_origin(namespace, env: env)}#{JWKS_PATH}"
  end

  # Only local Base controllers issue Jump RTs.
  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\ABase::/ then "BASE"
      end
    surface =
      case controller_class_name.to_s
      when /\A\w+::App::/ then "APP"
      when /\A\w+::Org::/ then "ORG"
      end
    if service.nil? || surface.nil?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    normalize_namespace("#{service}_#{surface}")
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    unless ISSUER_ORIGIN_ENV.key?(value)
      raise JumpRtConfigurationError, "unsupported Jump RT issuer surface: #{namespace.inspect}"
    end

    value
  end

  def normalize_host(host)
    host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end
end
