# typed: false
# frozen_string_literal: true

require "securerandom"

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  include OidcRpRoutePath

  # Required private hooks: rp_client_id, rp_resource_type, rp_log_surface, rp_op_origin,
  # rp_record_class, rp_session_class, rp_notice_face, and rp_sign_out_completion_path.

  class SessionNoLongerActive < StandardError; end

  class RegistrationUnavailable < StandardError; end

  # RP cells store the local session public id before the opaque token verifier.
  RP_REFRESH_TOKEN_SEPARATOR = "."
  private_constant :RP_REFRESH_TOKEN_SEPARATOR

  private

  def authenticate_oidc_rp_session!
    state = browser_rp_access_state
    return if performed?

    unless state.status == :valid && state.rp_session.instance_of?(rp_session_class) && state.rp_session.active?
      return head :unauthorized
    end

    @oidc_rp_logout_session = state.rp_session
    @oidc_rp_logout_resource = state.resource
    @oidc_rp_logout_access_payload = state.payload
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    log_sign_out_failure("rp_session_authentication", e)
    render_oidc_rp_logout_unavailable(after_local_commit: false)
  end

  def launch_oidc_rp_logout!
    session_record = @oidc_rp_logout_session
    state = SecureRandom.urlsafe_base64(32, padding: false)
    post_logout_redirect_uri = registered_rp_logout_redirect_uri(sign_out_region)
    refresh_token = current_oidc_rp_refresh_token(session_record)

    # The capability is prepared before the local commit. If either the cache or DB is unavailable,
    # the browser keeps its current credentials and the controller does not claim sign-out.
    prepare_sign_out_notice!(
      state:, session_record:, actor_ref: @oidc_rp_logout_resource.public_id, face: rp_notice_face,
    )

    begin
      revoke_rp_session_before_redirect!(session_record)
    rescue SessionNoLongerActive
      return head :conflict
    rescue ActiveRecord::ActiveRecordError, PG::Error => e
      log_sign_out_failure("local_session_revoke", e)
      return render_oidc_rp_logout_unavailable(after_local_commit: false)
    end

    clear_oidc_rp_logout_credentials!
    reset_session
    Actor.clear
    attach_sign_out_notice_to_session!
    clear_request_authentication_state!

    revoke_bound_refresh_token!(refresh_token) if refresh_token
    redirect_to_jump_url(
      rp_end_session_url(post_logout_redirect_uri:, state:),
      strict: true,
      status: :see_other,
    )
  rescue Umaxica::Valkey::Error, OidcClientRegistry::ClientNotFound, OidcOpRevocationClient::UnsupportedAuthenticationMethod,
         Oidc::AcmeServiceOrigin::ConfigurationUnavailable, CommonRedirect::JumpRedirectFailure,
         JumpRtConfigurationError, URI::InvalidURIError, RegistrationUnavailable => e
    log_sign_out_failure("external_logout_handoff", e)
    render_oidc_rp_logout_unavailable(after_local_commit: @local_sign_out_committed == true)
  end

  def complete_oidc_rp_logout!
    notice_id = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    return head :not_found unless notice_id.is_a?(String) && notice_id.present?

    notice = read_sign_out_notice(notice_id)
    return head :not_found unless valid_completion_notice?(notice, params[:state].to_s)
    return head :not_found unless revoked_notice_session?(notice)

    consumed_notice = consume_sign_out_notice(notice_id)
    return head :not_found unless valid_completion_notice?(consumed_notice, params[:state].to_s)

    session.delete(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY)
    session[:inertia_clear_history] = true
    render_oidc_rp_logout_completion
  rescue Umaxica::Valkey::Error, ActiveRecord::ActiveRecordError, PG::Error => e
    log_sign_out_failure("completion_dependency", e)
    render_oidc_rp_logout_unavailable(after_local_commit: true)
  end

  def registered_rp_logout_redirect_uri(region)
    client = OidcClientRegistry.find!(rp_client_id)
    raise RegistrationUnavailable, "registered RP resource type is inconsistent" unless
      client.resource_type == rp_resource_type

    client.post_logout_redirect_uris.find do |candidate|
      uri = URI.parse(candidate)
      actual_query = Rack::Utils.parse_nested_query(uri.query.to_s)
      uri.path == rp_local_route_path(rp_sign_out_completion_path) &&
        uri.scheme == request.protocol.delete_suffix("://") && uri.host == request.host &&
        uri.port == request.port && actual_query == { "ri" => region }
    end || raise(RegistrationUnavailable, "registered RP post-logout URI is unavailable")
  end

  def rp_end_session_url(post_logout_redirect_uri:, state:)
    uri = URI.parse(rp_op_origin.end_session_endpoint)
    uri.query = {
      "client_id" => rp_client_id,
      "post_logout_redirect_uri" => post_logout_redirect_uri,
      "state" => state,
    }.to_query
    uri.to_s
  end

  def current_oidc_rp_refresh_token(session_record)
    raw_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    return if raw_token.blank?

    parts = raw_token.split(RP_REFRESH_TOKEN_SEPARATOR, 2)
    return unless parts.length == 2 && parts.all?(&:present?)

    binding_sid = session_record.op_session_binding.sid
    access_sid = @oidc_rp_logout_access_payload.fetch("sid")
    return unless secure_logout_value_match?(binding_sid, access_sid)
    return unless secure_logout_value_match?(binding_sid, parts.first)

    raw_token
  end

  def secure_logout_value_match?(expected, actual)
    expected_value = expected.to_s
    actual_value = actual.to_s
    expected_value.present? && actual_value.present? && expected_value.bytesize == actual_value.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected_value, actual_value)
  end

  def revoke_rp_session_before_redirect!(session_record)
    rp_record_class.connected_to(role: :writing) do
      revoked = session_record.revoke_for_sign_out!
      raise SessionNoLongerActive, "RP session is no longer active" unless revoked
    end
    @local_sign_out_committed = true
  end

  def revoke_bound_refresh_token!(token)
    result = OidcOpRevocationClient.revoke(token:, client_id: rp_client_id, origin: rp_op_origin)
    return if result.success?

    Rails.logger.warn(
      JitLogEvent.format(
        "auth.sign_out.rp_refresh_revocation_unavailable",
        client_id: rp_client_id, surface: rp_log_surface,
        outcome: result.outcome,
      ),
    )
  end

  def clear_oidc_rp_logout_credentials!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
    clear_rp_cell_session_cookie!
  end

  def clear_request_authentication_state!
    @current_rp_authentication_payload = nil
    @current_resource = nil
    @browser_rp_access_state = BrowserRpAuthentication::AccessState.new(
      status: :missing, resource: nil, rp_session: nil, payload: nil, security_context: nil,
    )
  end

  def valid_completion_notice?(notice, provided_state)
    return false unless notice.is_a?(Hash) && notice["face"] == rp_notice_face

    expected_state = notice["state"].to_s
    expected_state.present? && provided_state.present? && expected_state.bytesize == provided_state.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected_state, provided_state)
  end

  def revoked_notice_session?(notice)
    session_public_id = notice["sid"]
    return false unless session_public_id.is_a?(String) && session_public_id.present?

    rp_record_class.connected_to(role: :writing) do
      rp_session_class.where(public_id: session_public_id).where.not(revoked_at: nil).exists?
    end
  end

  def log_sign_out_failure(stage, error)
    Rails.logger.error(
      JitLogEvent.format(
        "auth.sign_out.rp_local_flow_failed",
        client_id: rp_client_id, surface: rp_log_surface,
        stage:,
        error_class: error.class.name,
        result: "unavailable",
      ),
    )
  end
end
