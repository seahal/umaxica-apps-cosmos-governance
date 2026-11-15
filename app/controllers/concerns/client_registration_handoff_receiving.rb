# typed: false
# frozen_string_literal: true

# HTTP handling shared by the Base App registration receivers for H1, H3 and H5
# (adr/sign-up-finalization-in-auth.md, Cosmos split amendment). Requires from the includer:
# `cookies`, `request`, `render`, and CommonRedirect#redirect_to_jump_url. Each concrete controller
# names its handoff kind and the operation it calls; this concern only checks ingress, renders the
# fixed refusal pages, manages the registration cookie and sends the signed answer through Jump.
module ClientRegistrationHandoffReceiving
  REGISTRATION_COOKIE = "__Host-registration"
  BROWSER_SECRET_BYTES = 32
  AVAILABILITY_FLAG = :app_registration_available
  FETCH_MODE = "navigate"
  FETCH_DEST = "document"

  private

  def prepare_handoff_response!
    response.set_header("Cache-Control", "no-store")
    response.set_header("Referrer-Policy", "no-referrer")
  end

  # Returns the verified claims, or renders the fixed refusal page and returns nil.
  def verified_handoff_claims(kind)
    return refuse_handoff!(:bad_request, kind, "head") if request.head?
    return refuse_handoff!(:bad_request, kind, "fetch_metadata") unless navigation_request?
    return refuse_handoff!(:service_unavailable, kind, "unavailable") unless FeatureFlags.enabled?(AVAILABILITY_FLAG)
    return refuse_handoff!(:bad_request, kind, "url_too_long") unless request_url_within_jump_limit?

    verification = ClientRegistrationHandoffVerifier.new(
      kind:, token: params[ClientRegistrationPeerValue::TOKEN_PARAMETER],
      issuer: ClientRegistrationPeerValue.auth_origin, audience: ClientRegistrationPeerValue.base_origin,
      jwks_client: OidcOpJwksClient.for_jwks_uri(ClientRegistrationPeerValue.auth_jwks_uri),
    ).call
    return verification.claims if verification.verified?
    return refuse_handoff!(:service_unavailable, kind, "jwks_unavailable") if verification.unavailable?

    refuse_handoff!(:bad_request, kind, "invalid_#{verification.reason}")
  end

  def navigation_request?
    request.headers["Sec-Fetch-Mode"] == FETCH_MODE && request.headers["Sec-Fetch-Dest"] == FETCH_DEST
  end

  def request_url_within_jump_limit?
    url = request.original_url
    url.valid_encoding? && url.encode(Encoding::UTF_16LE).bytesize / 2 <= JumpRtIssuer::MAX_URL_LENGTH
  rescue EncodingError
    false
  end

  def presented_browser_secret_digest
    secret = cookies[REGISTRATION_COOKIE]
    secret.is_a?(String) && secret.present? ? Digest::SHA256.hexdigest(secret) : nil
  end

  def install_registration_cookie!(secret, registration)
    cookies[REGISTRATION_COOKIE] = {
      value: secret, secure: true, httponly: true, same_site: :lax, path: "/", expires: registration.deadline_at,
    }
  end

  def clear_registration_cookie!
    cookies.delete(REGISTRATION_COOKIE, secure: true, httponly: true, same_site: :lax, path: "/")
  end

  # A replayed handoff repeats no work. The current answer is re-issued only to the bound browser and
  # ceremony; anyone else sees the generic page.
  def answer_replay!(kind, claims)
    found = ClientRegistrationBrowserQuery.call(browser_secret_digest: presented_browser_secret_digest)
    registration = found&.registration
    bound = registration&.bound_to?(
      browser_secret_digest: presented_browser_secret_digest, access_ceremony_digest: claims.fetch("cer"),
    )
    if bound && registration.pending? && !registration.expired_at?(Time.current)
      return deliver_answer!(ClientRegistrationAnswerResult.new(reason: "started", registration:), kind, claims)
    end
    if bound && registration.completed?
      result = ClientRegistrationAnswerResult.new(reason: "completed", registration:, completion: found.completion)
      return deliver_answer!(result, kind, claims)
    end

    log_handoff_refusal(kind, "replay")
    render plain: t("base.app.registration.no_longer_valid"), status: :bad_request, content_type: "text/plain"
  end

  def deliver_answer!(result, kind, claims)
    token = ClientRegistrationAnswerCodec.encode(
      reason: result.reason, replies_to: kind, ceremony_digest: claims.fetch("cer"),
      issuer: ClientRegistrationPeerValue.base_origin, audience: ClientRegistrationPeerValue.auth_origin,
      registration: result.registration, completion: result.completion,
    )
    redirect_to_jump_url(ClientRegistrationPeerValue.answer_url(token), strict: true, status: :see_other)
  rescue CommonRedirect::JumpRedirectFailure
    refuse_handoff!(:service_unavailable, kind, "answer_undeliverable")
  end

  def refuse_handoff!(status, kind, reason)
    log_handoff_refusal(kind, reason)
    message =
      case status
      when :bad_request then t("base.app.registration.refused")
      when :service_unavailable then t("base.app.registration.unavailable")
      else raise ArgumentError, "unsupported registration refusal status #{status.inspect}"
      end
    render plain: message, status:, content_type: "text/plain"
    nil
  end

  def log_handoff_refusal(kind, reason)
    Rails.logger.info(JitLogEvent.format("registration.handoff_refused", kind:, reason:))
  end
end
