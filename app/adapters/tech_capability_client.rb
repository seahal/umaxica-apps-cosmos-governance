# typed: false
# frozen_string_literal: true

# Tech RP client for the org authority's capability decision (R5-WU11, one.md 4.2/6.4).
#
# Every request asks the authority again; permission denial and unavailable authority are distinct.
# TODO: AUDIT external access: calls the Tech capability API.
class TechCapabilityClient
  CLIENT_ID = "tech-org-ww"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  class << self
    public

    def allowed?(rp_session:)
      return false if rp_session.blank?

      base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type("operator")
      endpoint = OutboundHttp::LocalBackChannel.url("#{base_origin}/api/v0/tech-capability-checks")
      token = BaseApiAuthorityTokenIssuer.issue(rp_session:, audience_resource_type: "operator")

      uri = URI.parse(endpoint)
      connection = OutboundHttp::Connection.build(
        url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
        require_https: OutboundHttp::LocalBackChannel.require_https?(endpoint),
      )
      response = connection.post(uri, {}, { "Authorization" => "Bearer #{token}", "Accept" => "application/json" })
      return false if [401, 403].include?(response.status.to_i)
      raise AccessOpDataUnavailableError unless response.status.to_i == 200

      body = JSON.parse(response.body.to_s)
      raise AccessOpDataUnavailableError unless body.is_a?(Hash) && [true, false].include?(body["allowed"])

      body["allowed"]
    rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
      raise AccessOpDataUnavailableError
    rescue BaseApiAuthorityTokenIssuer::InactiveRpSession
      false
    end
  end
end
