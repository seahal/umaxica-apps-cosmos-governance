# typed: false
# frozen_string_literal: true

module OutboundHttp
  # In local development, configured Base hosts resolve to this container via compose network
  # aliases. HTTPS terminates at Cloudflare Tunnel, so local back-channel calls use the HTTP port.
  # Production and hosts outside the configured Base surfaces keep their original URLs.
  # TODO: AUDIT external access: rewrites first-party outbound URLs to local HTTP in development.
  module LocalBackChannel
    module_function

    def url(public_url)
      return public_url unless Rails.env.local?

      uri = URI.parse(public_url)
      return public_url unless uri.is_a?(URI::HTTP) && first_party_host?(uri.host)

      uri.scheme = "http"
      uri.port = local_port
      uri.to_s
    rescue URI::InvalidURIError
      public_url
    end

    # HTTPS is required except for the exact local form `url` produces.
    def require_https?(url)
      return true unless Rails.env.local?

      uri = URI.parse(url)
      !(uri.scheme == "http" && first_party_host?(uri.host) && uri.port == local_port && uri.userinfo.blank?)
    rescue URI::InvalidURIError
      true
    end

    def first_party_host?(host)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      [
        hosts.base_service, hosts.base_corporate, hosts.base_staff,
      ].map { |configured| configured.host.to_s.downcase }.include?(host.to_s.downcase)
    end

    def local_port
      Integer(ENV.fetch("PORT"), exception: false) || 3000
    end
  end
end
