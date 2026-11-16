# frozen_string_literal: true

require "faraday"
require "rack/mock"

# Tests deliver first-party issuer JWKS and Base owner API calls through Rails instead of the network.
# Every other outbound request remains subject to OutboundHttpGuard and must be stubbed explicitly.
module TestSupport
  module InProcessOwnedSurfaceTransport
    OWNED_API_PATH_PREFIXES = %w(
      /api/v0/tech-capability-checks /api/v0/support /api/v0/avatar/ /api/v0/membership/
      /api/v0/iam/ /api/v0/identity/
    ).freeze

    # Forwards a Faraday request to Rails.application as a Rack request.
    class Adapter < Faraday::Adapter
      def call(env)
        super
        if InProcessOwnedSurfaceTransport.issuer_jwks_request?(env.url)
          save_response(
            env, 200, JSON.generate(InProcessOwnedSurfaceTransport.jwks_for(env.url)),
            { "Content-Type" => "application/json" },
          )
          return @app.call(env)
        end

        rack_env = Rack::MockRequest.env_for(
          env.url.to_s,
          :method => env.method.to_s.upcase,
          :input => env.body.to_s,
          "CONTENT_TYPE" => env.request_headers["Content-Type"],
          "HTTP_ACCEPT" => "application/json",
          "HTTPS" => (env.url.scheme == "https") ? "on" : "off",
        )
        env.request_headers.each do |name, value|
          next if name.casecmp?("Content-Type")

          rack_env["HTTP_#{name.upcase.tr("-", "_")}"] = value
        end
        status, headers, body =
          with_application_process_role do
            ActiveRecord::Base.connected_to(role: :writing) do
              Rails.application.routes.call(rack_env)
            end
          end
        text = +""
        body.each { |chunk| text << chunk }
        body.close if body.respond_to?(:close)
        save_response(env, status, text, headers)
        @app.call(env)
      end

      private

      def with_application_process_role
        previous = ENV["UMAXICA_RUNTIME_ROLE"]
        ENV["UMAXICA_RUNTIME_ROLE"] = RuntimeRole::SHARED
        yield
      ensure
        ENV["UMAXICA_RUNTIME_ROLE"] = previous
      end
    end

    # Local first-party requests are part of the system under test, not an external provider.
    class Connection < Faraday::Connection
      def run_request(...)
        TestSupport::OutboundHttpGuard.allow { super }
      end
    end

    module_function

    def in_process_request?(url)
      uri = URI.parse(url.to_s)
      return false unless uri.path == "/.well-known/jwks.json" ||
        OWNED_API_PATH_PREFIXES.any? { |prefix| uri.path.start_with?(prefix) }

      [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
       Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,].include?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    def issuer_jwks_request?(url)
      uri = URI.parse(url.to_s)
      uri.path == "/.well-known/jwks.json" &&
        [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
         Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,].include?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    def jwks_for(url)
      uri = URI.parse(url.to_s)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      namespace =
        if uri.host == hosts.base_service.host
          "BASE_APP"
        elsif uri.host == hosts.base_staff.host
          "BASE_ORG"
        else
          raise ArgumentError, "unsupported in-process issuer JWKS host"
        end
      JitSecurityJwtJwksService.jwk_set(namespace)
    end

    def connection
      Connection.new do |builder|
        builder.request(:url_encoded)
        builder.adapter(Adapter)
      end
    end
  end
end

# Wrap (not prepend) OutboundHttp::Connection.build so an explicit test stub of `build` still takes
# precedence: Minitest's stub redefines this singleton method for the duration of its block.
OutboundHttp::Connection.singleton_class.alias_method(:build_without_in_process_owned_surface, :build)
OutboundHttp::Connection.define_singleton_method(:build) do |url:, **options|
  next TestSupport::InProcessOwnedSurfaceTransport.connection if
    TestSupport::InProcessOwnedSurfaceTransport.in_process_request?(url)

  build_without_in_process_owned_surface(url:, **options)
end
