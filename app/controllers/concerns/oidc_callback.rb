# typed: false
# frozen_string_literal: true

require "digest"

module OidcCallback
  extend ActiveSupport::Concern

  include OidcRpRoutePath

  # Required private hooks: rp_client_id, rp_realm, rp_log_surface, rp_op_origin, rp_op_jwks_uri,
  # rp_default_landing_path, rp_callback_path, rp_interruption_path, rp_sign_path, rp_cell_binding,
  # and rp_record_class. The including controller owns realm-specific values and route helpers.

  InvalidCallbackState =
    Class.new(StandardError) do
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super("OIDC callback state is invalid")
      end
    end
  OIDC_PENDING_FLOWS_SESSION_KEY = OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY
  SESSION_TTL = 1.hour
  SESSION_RENEWAL_COOKIE_GRACE = 5.minutes

  public

  def show
    response.set_header("Cache-Control", "no-store")
    response.set_header("Referrer-Policy", "no-referrer")
    flow = consume_validated_flow!
    return unless flow

    return callback_failure!("mixed_response") if mixed_response?
    return callback_failure!("callback_url_too_long") unless callback_url_within_jump_limit?
    return handle_op_error! if params[:error].present?
    return callback_failure!("id_token_missing") if params[:id_token].blank?

    process_id_token(flow)
  rescue ActiveRecord::ActiveRecordError, OidcOpJwksClient::FetchError => e
    callback_failure!("dependency_unavailable", detail: e.class.name)
  rescue ::Oidc::AcmeServiceOrigin::ConfigurationUnavailable
    callback_failure!("dependency_unavailable", detail: "op_host_unconfigured")
  rescue ArgumentError, KeyError, TypeError
    callback_failure!("callback_invalid")
  end

  private

  def mixed_response?
    params[:code].present? || params[:access_token].present? || params[:refresh_token].present?
  end

  def process_id_token(flow)
    verification = verify_id_token(params[:id_token].to_s, flow.fetch("nonce"))
    unless verification.success?
      return callback_failure!(
        (verification.error == "key_unavailable") ? "dependency_unavailable" : "id_token_invalid",
        detail: verification.detail,
      )
    end

    result = commit_callback(verification.payload, flow)
    unless result.session
      return callback_failure!((result.outcome == :replayed) ? "id_token_replayed" : "identity_resolution_failed")
    end

    install_authenticated_session!(result.session)
    redirect_to(
      RpTargetLinkUri.normalize(verification_target) || rp_default_landing_path,
      allow_other_host: false, status: :see_other,
    )
  end

  def consume_validated_flow!
    state = OidcStateJwt.verify(client_id: rp_client_id, token: params[:state].to_s)
    raise InvalidCallbackState.new("state_token_invalid") unless state.valid?

    flows = session[OIDC_PENDING_FLOWS_SESSION_KEY]
    flow = flows[state.jti] if flows.is_a?(Hash)
    raise InvalidCallbackState.new("pending_flow_missing") unless flow.is_a?(Hash)

    raw_created_at = flow.fetch("created_at")
    created_at = raw_created_at.is_a?(Integer) ? raw_created_at : Integer(raw_created_at, 10)
    if Time.current.to_i >= created_at + OidcStateJwt::TTL.to_i
      consume_pending_flows!
      raise InvalidCallbackState.new("pending_flow_expired")
    end
    nonce = flow.fetch("nonce")
    unless nonce.is_a?(String) && nonce.present?
      consume_pending_flows!
      raise InvalidCallbackState.new("pending_flow_invalid")
    end

    @verified_oidc_target_link_uri = RpTargetLinkUri.normalize(state.target_link_uri)
    consume_pending_flows!
    verify_authorization_response_issuer!
    flow
  rescue InvalidCallbackState => e
    log_callback_failure(e.reason)
    consume_pending_flows!
    redirect_to(rp_interruption_path, allow_other_host: false, status: :see_other)
    nil
  rescue ArgumentError, KeyError, TypeError
    log_callback_failure("state_invalid")
    consume_pending_flows!
    redirect_to(rp_interruption_path, allow_other_host: false, status: :see_other)
    nil
  end

  def verify_authorization_response_issuer!
    actual = params[:iss].to_s
    expected = rp_op_origin.origin
    valid = actual.present? && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
    raise InvalidCallbackState.new("issuer_invalid") unless valid
  end

  def callback_url_within_jump_limit?
    url = request.original_url
    return false unless url.valid_encoding?

    url.encode(Encoding::UTF_16LE).bytesize / 2 <= JumpRtIssuer::MAX_URL_LENGTH
  rescue EncodingError
    false
  end

  def verify_id_token(id_token, nonce)
    OidcOpIdTokenVerifier.new(
      id_token:, client_id: rp_client_id, realm: rp_realm, issuer: rp_op_origin.origin,
      expected_nonce: nonce, jwks_client: OidcOpJwksClient.for_jwks_uri(rp_op_jwks_uri),
    ).call
  rescue ArgumentError
    OidcOpIdTokenVerifier::Result.new(success: false, payload: nil, error: "invalid_id_token", detail: "configuration")
  end

  def commit_callback(payload, flow)
    absolute_expires_at = Time.current + SESSION_TTL
    rp_record_class.connected_to(role: :writing) do
      RpCallbackCommitter.call(
        cell: rp_cell_binding, issuer: payload.fetch("iss"), subject: payload.fetch("sub"),
        sid: payload.fetch("sid"), absolute_expires_at:,
        id_token_jti_digest: Digest::SHA256.hexdigest(payload.fetch("jti")),
        id_token_expires_at: Time.at(payload.fetch("exp")).utc + OidcOpIdTokenVerifier::CLOCK_SKEW_LEEWAY_SECONDS,
        authentication_evidence: payload.slice("acr", "amr", "auth_time").merge(
          "id_token_jti_digest" => Digest::SHA256.hexdigest(payload.fetch("jti")),
        ),
        renewal_session_id: flow["renewal_session_id"],
      )
    end
  end

  def install_authenticated_session!(rp_session)
    reset_session
    session[:inertia_clear_history] = true
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] =
      OidcRpBrowserCredentialContract.session_cookie_options(
        expires_at: rp_session.absolute_expires_at + SESSION_RENEWAL_COOKIE_GRACE,
      ).merge(value: rp_session.public_id)
    delete_browser_access_cookies!
  end

  def delete_browser_access_cookies!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
  end

  def handle_op_error!
    if params[:error].to_s == "login_required"
      log_callback_failure("login_required")
      redirect_to(
        rp_sign_path(
          ri: RequestContextContract.normalize_region(params[:ri]),
          target_link_uri: verification_target,
        ),
        allow_other_host: false, status: :see_other,
      )
    else
      callback_failure!("authorization_error")
    end
  end

  def callback_failure!(reason, detail: nil)
    log_callback_failure(reason, detail:)
    consume_pending_flows!
    redirect_to(rp_interruption_path, allow_other_host: false, status: :see_other)
  end

  def consume_pending_flows!
    session.delete(OIDC_PENDING_FLOWS_SESSION_KEY)
  end

  def log_callback_failure(reason, detail: nil)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.callback.failed", surface: rp_log_surface, client_id: rp_client_id,
                                   request_id: request.request_id, status: Rack::Utils.status_code(:see_other),
                                   reason:, detail:,
      ),
    )
  end

  def verification_target
    @verified_oidc_target_link_uri
  end
end
