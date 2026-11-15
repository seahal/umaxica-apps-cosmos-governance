# typed: false
# frozen_string_literal: true

require "timeout"

# Sends one Base RP cell's bound Refresh Token to its configured OP's RFC 7009 endpoint.
class OidcOpRevocationClient
  Result =
    Data.define(:outcome) do
      def success? = outcome == :success
    end

  class UnsupportedAuthenticationMethod < StandardError; end

  class RequestDeadlineExceeded < StandardError; end

  BASE_CELL_CONNECTIONS = %w(rp_base_app rp_base_org).freeze
  private_constant :BASE_CELL_CONNECTIONS
  TOTAL_REQUEST_BUDGET = 2.0
  MAX_ATTEMPTS = 2

  def self.revoke(token:, client_id:, origin:)
    new(token:, client_id:, origin:).call
  end
  public_class_method :revoke

  def initialize(token:, client_id:, origin:)
    cell = RpCellBinding.for_client(client_id)
    unless BASE_CELL_CONNECTIONS.include?(cell.connection) && cell.client_id == client_id.to_s
      raise ArgumentError, "refresh-token revocation requires a Base RP client"
    end
    raise ArgumentError, "configured OP origin is required" unless origin.is_a?(Oidc::AcmeServiceOrigin)

    @token = token
    @client_id = cell.client_id
    @origin = origin
  end

  public

  def call
    return result(:missing_token) if token.blank?

    client = OidcClientRegistry.find!(client_id)
    unless client.registered_token_endpoint_auth_method == "private_key_jwt"
      raise UnsupportedAuthenticationMethod, "Base RP revocation requires private_key_jwt"
    end

    revoke_at(origin.revocation_endpoint)
  rescue Oidc::AcmeServiceOrigin::ConfigurationUnavailable, URI::InvalidURIError,
         OutboundHttp::Connection::InsecureEndpointError
    result(:endpoint_unavailable)
  end

  private

  attr_reader :token, :client_id, :origin

  def revoke_at(public_endpoint)
    public_uri = URI.parse(public_endpoint)
    local_uri = URI.parse(OutboundHttp::LocalBackChannel.url(public_endpoint))
    deadline = monotonic_now + TOTAL_REQUEST_BUDGET

    1.upto(MAX_ATTEMPTS) do |attempt|
      attempt_result = revoke_attempt(public_uri:, local_uri:, deadline:, attempt:)
      return attempt_result if attempt_result
    end

    result(:network_unavailable)
  end

  def revoke_attempt(public_uri:, local_uri:, deadline:, attempt:)
    remaining = deadline - monotonic_now
    return result(:timeout) unless remaining.positive?

    timeout = remaining / (MAX_ATTEMPTS - attempt + 1)
    assertion = OidcClientAssertionJwt.issue(client_id:, token_url: public_uri.to_s)
    return result(:client_authentication_unavailable) if assertion.blank?

    body = {
      client_id:,
      token: token,
      token_type_hint: "refresh_token",
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: assertion,
    }
    connection = OutboundHttp::Connection.build(
      url: local_uri,
      open_timeout: timeout,
      read_timeout: timeout,
      write_timeout: timeout,
      require_https: OutboundHttp::LocalBackChannel.require_https?(local_uri.to_s),
    )
    remaining = deadline - monotonic_now
    return result(:timeout) unless remaining.positive?

    response =
      Timeout.timeout([timeout, remaining].min, RequestDeadlineExceeded) do
        connection.post(local_uri, body)
      end
    return result(:timeout) if monotonic_now >= deadline

    classify(response)
  rescue Faraday::Error, RequestDeadlineExceeded
    return if attempt < MAX_ATTEMPTS && monotonic_now < deadline

    result(:network_unavailable)
  end

  def classify(response)
    status = response.status.to_i
    return result(:success) if status == 200
    return result(:unexpected_redirect) if status.between?(300, 399)
    return result(:rejected) if status.between?(400, 499)
    return result(:endpoint_failure) if status >= 500

    result(:unexpected_response)
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def result(outcome)
    Result.new(outcome:)
  end
end
