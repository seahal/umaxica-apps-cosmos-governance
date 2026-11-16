# typed: false
# frozen_string_literal: true

# Redirects anonymous HTML reads from an RP's private page to that RP's own sign entry.
# Required private hook: rp_sign_path(**options), supplied by the including realm controller.
module BaseRpSignInRedirect
  private

  def preserve_browser_rp_renewal_candidate!
    session_id = cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s
    return unless session_id.match?(/\A[A-Za-z0-9_-]{21}\z/)

    session[OidcSsoInitiator::OIDC_PENDING_RENEWAL_SESSION_KEY] = {
      "session_id" => session_id,
      "created_at" => Time.current.to_i,
    }
  end

  def render_browser_rp_unauthenticated!
    return super unless (request.get? || request.head?) && request.format.html?

    response.set_header("Cache-Control", "no-store")
    query = {
      ri: RequestContextContract.normalize_region(params[:ri]),
      target_link_uri: RpTargetLinkUri.normalize(request.path),
    }.compact
    redirect_to(rp_sign_path(**query), allow_other_host: false, status: :see_other)
  end
end
