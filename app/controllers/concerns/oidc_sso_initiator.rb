# typed: false
# frozen_string_literal: true

module OidcSsoInitiator
  extend ActiveSupport::Concern

  # Required private hooks: rp_client_id, rp_log_surface, rp_op_origin and rp_callback_path.

  include CommonRedirect
  include OidcRpRoutePath

  OIDC_PENDING_FLOWS_SESSION_KEY = "oidc_pending_flows"
  OIDC_PENDING_RENEWAL_SESSION_KEY = "oidc_pending_rp_renewal"

  private

  def initiate_oidc_session!(target_link_uri: nil)
    origin = rp_op_origin
    nonce = SecureRandom.urlsafe_base64(32)
    renewal = consume_rp_renewal_marker
    state, jti = OidcStateJwt.issue(
      client_id: rp_client_id, target_link_uri: RpTargetLinkUri.normalize(target_link_uri),
    )
    pending_flow = { "nonce" => nonce, "created_at" => Time.current.to_i }
    pending_flow["renewal_session_id"] = renewal.fetch("session_id") if renewal
    session[OIDC_PENDING_FLOWS_SESSION_KEY] = { jti => pending_flow }
    log_oidc_pending_flow_created

    query = {
      response_type: "id_token",
      client_id: rp_client_id,
      redirect_uri: oidc_callback_url,
      state:,
      nonce:,
      scope: "openid profile",
      ri: RequestContextContract.normalize_region(params[:ri]),
    }.compact
    query[:prompt] = "none" if renewal
    origin.authorization_endpoint(query:)
  end

  def consume_rp_renewal_marker
    marker = session.delete(OIDC_PENDING_RENEWAL_SESSION_KEY)
    return unless marker.is_a?(Hash)

    created_at = marker["created_at"]
    session_id = marker["session_id"]
    return unless created_at.is_a?(Integer) && Time.current.to_i < created_at + 5.minutes.to_i
    return unless session_id.is_a?(String) && session_id.match?(/\A[A-Za-z0-9_-]{21}\z/)

    marker
  end

  def redirect_to_oidc_authorization_url(url, **)
    uri = URI.parse(url.to_s)
    valid_url = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank? &&
      uri.path == "/oauth/authorize" && uri.query.present? && uri.fragment.blank?
    return head :bad_request unless valid_url

    log_oidc_redirect_handoff
    redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], strict: true, **)
  rescue URI::InvalidURIError
    head :bad_request
  rescue CommonRedirect::JumpRedirectFailure
    response.set_header("Cache-Control", "no-store")
    head :service_unavailable
  end

  def oidc_callback_url
    callback_path = rp_local_route_path(rp_callback_path)
    registered =
      OidcClientRegistry.find!(rp_client_id).redirect_uris.find do |redirect_uri|
        uri = URI.parse(redirect_uri)
        uri.scheme == request.protocol.delete_suffix("://") && uri.host == request.host &&
          uri.port == request.port && uri.path == callback_path
      end
    registered || raise(ActionController::BadRequest, "RP callback is not registered for this host")
  rescue URI::InvalidURIError
    raise ActionController::BadRequest, "RP callback registration is invalid"
  end

  def log_oidc_pending_flow_created
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.sso.pending_flow.created",
        client_id: rp_client_id, surface: rp_log_surface, request_id: request.request_id, status: "created",
      ),
    )
  end

  def log_oidc_redirect_handoff
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.sso.redirect_policy.jump",
        client_id: rp_client_id, surface: rp_log_surface, request_id: request.request_id, status: "handoff",
      ),
    )
  end
end
