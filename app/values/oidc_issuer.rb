# typed: false
# frozen_string_literal: true

module OidcIssuer
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  JWT_ISSUER_IDS = {
    "client" => "surface:BASE_APP",
    "operator" => "surface:BASE_ORG",
  }.freeze

  class UnavailableError < StandardError; end

  module_function

  def for_client(client) = for_resource_type(resource_type_for_client(client))

  def for_resource_type(resource_type)
    host = host_for_resource_type(resource_type)
    scheme = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port = (Rails.env.production? || public_host?(host) || host.include?(":")) ? "" : ":3000"
    "#{scheme}://#{host}#{port}"
  end

  def jwks_uri(resource_type) = "#{for_resource_type(resource_type)}/.well-known/jwks.json"

  def authorization_endpoint(_resource_type) = unavailable!

  def token_endpoint(_resource_type) = unavailable!

  def userinfo_endpoint(_resource_type) = unavailable!

  def revocation_endpoint(_resource_type) = unavailable!

  def end_session_endpoint(_resource_type) = unavailable!

  def host_for_client(client) = host_for_resource_type(resource_type_for_client(client))

  def host_for_resource_type(resource_type)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    case normalize_resource_type(resource_type)
    when "client" then hosts.base_service.host
    when "operator" then hosts.base_staff.host
    end
  end

  def jwt_issuer_id_for_client(client) = jwt_issuer_id_for_resource_type(resource_type_for_client(client))

  def jwt_issuer_id_for_resource_type(resource_type) = JWT_ISSUER_IDS.fetch(normalize_resource_type(resource_type))

  def resource_type_for_client(client)
    normalize_resource_type(client.resource_type)
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "client" then "client"
    else raise ArgumentError, "unsupported OIDC resource type: #{resource_type.inspect}"
    end
  end
  private_class_method :normalize_resource_type

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s
    normalized_host.present? && LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end
  private_class_method :public_host?

  def unavailable!
    raise UnavailableError, "OIDC issuer endpoints have been retired"
  end
  private_class_method :unavailable!
end
