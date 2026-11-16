# typed: false
# frozen_string_literal: true

# Org Base Self-RP client for the org administration owners: IAM, Support and Enforcement
# (R5-WU12). Each call carries a fresh Governance bearer derived from its active RP session and the
# browser facts the owner records in its administrative audit (request id, IP, User-Agent). Typed
# outcomes; writes are never retried.
# TODO: AUDIT external access: calls the Org admin authority API.
class OrgAdminAuthorityClient
  # http_status keeps the owner's exact code (e.g. 201/202) for JSON responses relayed as-is.
  Result =
    Data.define(:status, :data, :errors, :http_status) do
      def ok? = status == :ok
    end
  # Base Self-RP client and actor type per realm; org administration always uses the org realm.
  CLIENTS = AvatarAuthorityClient::CLIENTS
  STATUSES = { 200 => :ok,
               201 => :ok,
               202 => :ok,
               204 => :ok,
               400 => :bad_request,
               401 => :unauthorized,
               403 => :forbidden,
               404 => :not_found,
               409 => :conflict,
               410 => :gone,
               422 => :unprocessable,
               503 => :unavailable, }.freeze
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def initialize(rp_session:, browser_request:, surface: "org")
    @resource_type = CLIENTS.fetch(surface.to_s).fetch(1)
    base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type(@resource_type)
    @base = OutboundHttp::LocalBackChannel.url("#{base_origin}/api/v0")
    @rp_session = rp_session
    @browser_request = browser_request
  end

  public

  def get(path, params = {}, extra_headers: {}) = call(:get, path, params, extra_headers)

  def post(path, params = {}, extra_headers: {}) = call(:post, path, params, extra_headers)

  private

  attr_reader :base, :browser_request, :rp_session, :resource_type

  def call(verb, path, params, extra_headers)
    return Result.new(status: :unauthorized, data: nil, errors: {}, http_status: 401) if rp_session.blank?

    url = "#{base}#{path}"
    token = BaseApiAuthorityTokenIssuer.issue(rp_session:, audience_resource_type: resource_type)

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: OutboundHttp::LocalBackChannel.require_https?(url),
    )
    headers = {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json",
      "X-Browser-Request-Id" => browser_request.request_id.to_s,
      "X-Browser-Ip" => browser_request.remote_ip.to_s,
      "X-Browser-User-Agent" => browser_request.user_agent.to_s,
    }.merge(extra_headers)
    response =
      if verb == :get
        connection.get(uri, params, headers)
      else
        connection.post(
          uri, Faraday::Utils.build_nested_query(params),
          headers.merge("Content-Type" => "application/x-www-form-urlencoded"),
        )
      end
    body = response.body.present? ? JSON.parse(response.body) : {}
    return Result.new(status: :dependency, data: nil, errors: {}, http_status: 503) unless body.is_a?(Hash)

    Result.new(
      status: STATUSES.fetch(response.status.to_i, :dependency), data: body, errors: body.fetch("errors", {}),
      http_status: response.status.to_i,
    )
  rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency, data: nil, errors: {}, http_status: 503)
  rescue BaseApiAuthorityTokenIssuer::InactiveRpSession
    Result.new(status: :unauthorized, data: nil, errors: {}, http_status: 401)
  end
end
