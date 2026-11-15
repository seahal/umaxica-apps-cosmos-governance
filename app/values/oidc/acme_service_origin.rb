# typed: false
# frozen_string_literal: true

module Oidc
  # Fixed OP origin used to build endpoints. Callback parameters never choose this host.
  class AcmeServiceOrigin
    class ConfigurationUnavailable < StandardError; end

    def self.from_configured_host(value, default_scheme:)
      raise ConfigurationUnavailable, "OP host configuration is required" if value.blank?

      from(value, default_scheme:)
    rescue ArgumentError
      raise ConfigurationUnavailable, "OP host configuration is invalid"
    end

    def self.from(value, default_scheme:)
      raw = value.to_s.strip
      raise ArgumentError, "missing OP origin" if raw.blank?

      normalized = raw.match?(%r{\Ahttps?://}i) ? raw : "#{default_scheme}://#{raw}"
      uri = URI.parse(normalized)
      unless uri.is_a?(URI::HTTP) && %w(http https).include?(uri.scheme) &&
          uri.host.present? && uri.userinfo.blank? && [nil, "", "/"].include?(uri.path) &&
          uri.query.blank? && uri.fragment.blank?
        raise ArgumentError, "invalid OP origin"
      end

      new(scheme: uri.scheme, host: uri.host, port: normalize_port(uri.scheme, uri.port))
    rescue URI::InvalidURIError
      raise ArgumentError, "invalid OP origin"
    end

    def self.host_from(value)
      from(value, default_scheme: "https").host
    rescue ArgumentError
      nil
    end

    public_class_method :from_configured_host, :from, :host_from

    def self.normalize_port(scheme, port)
      default_port = scheme.to_s.casecmp("https").zero? ? 443 : 80
      (port == default_port) ? nil : port
    end
    private_class_method :normalize_port

    attr_reader :scheme, :host, :port

    def initialize(scheme:, host:, port:)
      @scheme = scheme.to_s.downcase.freeze
      @host = host.to_s.downcase.freeze
      @port = port
      freeze
    end

    public

    def ==(other)
      other.instance_of?(self.class) && [scheme, host, port] == [other.scheme, other.host, other.port]
    end
    alias eql? ==

    def hash = [self.class, scheme, host, port].hash

    def origin
      build_uri("/").to_s.delete_suffix("/")
    end

    def authorization_endpoint(query: nil)
      uri = build_uri("/oauth/authorize")
      uri.query = query.to_query if query.present?
      uri.to_s
    end

    def token_endpoint = build_uri("/oauth/token").to_s

    def jwks_uri = build_uri("/.well-known/jwks.json").to_s

    def revocation_endpoint = build_uri("/oauth/revoke").to_s

    def end_session_endpoint = build_uri("/oidc/logout").to_s

    private

    def build_uri(path)
      URI::Generic.build(scheme:, host:, port:, path:)
    end
  end
end
