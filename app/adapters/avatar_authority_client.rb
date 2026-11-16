# typed: false
# frozen_string_literal: true

# Base Self-RP client for the Avatar owner (R5-WU14, approved contract 2026-10-17).
#
# Each call carries a fresh Governance token derived from this realm's active RP session and the
# selected persona; the owner re-resolves the actor and decides.
# Typed outcomes only; a write is never retried blindly.
# TODO: AUDIT external access: calls the Avatar authority API on another first-party host.
class AvatarAuthorityClient
  Result =
    Data.define(:status, :data, :errors) do
      def ok? = status == :ok
    end

  CLIENTS = { "app" => ["base-app-ww", "client"],
              "org" => ["base-org-ww", "operator"], }.freeze
  STATUSES = { 200 => :ok,
               201 => :ok,
               204 => :ok,
               401 => :unauthorized,
               403 => :forbidden,
               404 => :not_found,
               410 => :gone,
               422 => :unprocessable, }.freeze
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def initialize(surface:, rp_session:, persona:, selection: nil)
    @surface = surface.to_s
    @resource_type = CLIENTS.fetch(@surface).fetch(1)
    base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type(@resource_type)
    @base = OutboundHttp::LocalBackChannel.url("#{base_origin}/api/v0/avatar/#{surface}")
    @rp_session = rp_session
    @persona = persona.to_s
    @selection = selection
  end

  public

  def avatars = request(:get, "/avatars")

  def avatar(ref) = request(:get, "/avatars/#{escape(ref)}")

  def create_avatar(attributes) = request(:post, "/avatars", { avatar: attributes })

  def update_avatar(ref, attributes) = request(:patch, "/avatars/#{escape(ref)}", { avatar: attributes })

  # kind is one of follows, blocks, mutes; the acting Avatar is the owner-side selection.
  def add_edge(kind, target_ref) = request(:post, "/avatars/#{escape(target_ref)}/#{kind}")

  def remove_edge(kind, target_ref) = request(:delete, "/avatars/#{escape(target_ref)}/#{kind}")

  # Ownership transfers; an Idempotency-Key (registry request) is forwarded unchanged.
  def request_transfer(attributes, idempotency_key: nil)
    request(:post, "/ownership-transfers", attributes, idempotency_key:)
  end

  def accept_transfer(ref, transfer_kind:)
    request(:post, "/ownership-transfers/#{escape(ref)}/accept", { transfer_kind: })
  end

  def cancel_transfer(ref, transfer_kind:)
    request(:post, "/ownership-transfers/#{escape(ref)}/cancel", { transfer_kind: })
  end

  # Raw bytes of the selected Avatar's image (not JSON). Returns [status, body, mime_type, cache_key].
  def selected_image
    return [:unauthorized, nil, nil, nil] if rp_session.blank?

    token = issue_authority_token
    url = "#{base}/selected-image"

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: OutboundHttp::LocalBackChannel.require_https?(url),
    )
    response = connection.get(
      uri, request_selection_params, { "Authorization" => "Bearer #{token}" },
    )
    status = { 200 => :ok, 204 => :no_image, 404 => :not_found, 403 => :forbidden }.fetch(
      response.status.to_i,
      :dependency,
    )
    [status, response.body, response.headers["Content-Type"], response.headers["X-Avatar-Image-Key"]]
  rescue Faraday::Error, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    [:dependency, nil, nil, nil]
  rescue BaseApiAuthorityTokenIssuer::InactiveRpSession
    [:unauthorized, nil, nil, nil]
  end

  def dashboard_identity = request(:get, "/dashboard-identity")

  def switcher_context = request(:get, "/switcher")

  def switch_context(attributes) = request(:put, "/switcher", attributes, selection_params: { persona: })

  def selected_avatar = request(:get, "/selected-avatar")

  def update_selected_avatar(attributes) = request(:patch, "/selected-avatar", { avatar: attributes })

  def destroy_selected_avatar = request(:delete, "/selected-avatar")

  def groups = request(:get, "/groups")

  def fetch_group(ref) = request(:get, "/groups/#{escape(ref)}")

  def create_group(attributes) = request(:post, "/groups", { group: attributes })

  def update_group(ref, attributes) = request(:patch, "/groups/#{escape(ref)}", { group: attributes })

  def archive_group(ref) = request(:delete, "/groups/#{escape(ref)}")

  def attach_avatar(group_ref, attributes)
    request(:post, "/groups/#{escape(group_ref)}/avatar-memberships", { membership: attributes })
  end

  def reorder_avatar(group_ref, ref, attributes)
    request(:patch, "/groups/#{escape(group_ref)}/avatar-memberships/#{escape(ref)}", { membership: attributes })
  end

  def detach_avatar(group_ref, ref) = request(:delete, "/groups/#{escape(group_ref)}/avatar-memberships/#{escape(ref)}")

  private

  attr_reader :base, :persona, :selection, :surface, :rp_session, :resource_type

  def request_selection_params
    return app_selection_params if surface == "app"
    return { persona: } unless selection

    {
      persona:,
      organization_public_id: selection.collective_public_id,
      organization_unit_public_id: selection.collective_unit_public_id,
      avatar_public_id: selection.avatar_public_id,
    }
  end

  def app_selection_params
    {
      persona:,
      organization_public_id: selection&.collective_public_id,
      organization_unit_public_id: selection&.collective_unit_public_id,
      avatar_public_id: selection&.avatar_public_id,
    }
  end

  def request(verb, path, params = {}, idempotency_key: nil, selection_params: request_selection_params)
    return Result.new(status: :unauthorized, data: nil, errors: {}) if rp_session.blank?

    url = "#{base}#{path}"
    token = issue_authority_token

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: OutboundHttp::LocalBackChannel.require_https?(url),
    )
    headers = { "Authorization" => "Bearer #{token}",
                "Accept" => "application/json", }
    headers["Idempotency-Key"] = idempotency_key if idempotency_key
    params = params.merge(selection_params)
    response =
      if verb == :get
        connection.get(uri, params, headers)
      else
        connection.run_request(
          verb, uri, Faraday::Utils.build_nested_query(params),
          headers.merge("Content-Type" => "application/x-www-form-urlencoded"),
        )
      end
    body = response.body.present? ? JSON.parse(response.body) : {}
    return Result.new(status: :dependency, data: nil, errors: {}) unless body.is_a?(Hash)

    Result.new(status: STATUSES.fetch(response.status.to_i, :dependency), data: body, errors: body.fetch("errors", {}))
  rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency, data: nil, errors: {})
  rescue BaseApiAuthorityTokenIssuer::InactiveRpSession
    Result.new(status: :unauthorized, data: nil, errors: {})
  end

  def issue_authority_token
    BaseApiAuthorityTokenIssuer.issue(rp_session:, audience_resource_type: resource_type)
  end

  def escape(value) = ERB::Util.url_encode(value.to_s)
end
