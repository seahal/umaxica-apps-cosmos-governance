# typed: false
# frozen_string_literal: true

# Local principal/session authentication for an RP cell process (R5-WU17, one.md section 7.4).
#
# A process booted with an `rp-*` runtime role authenticates only from its own cell: the Access JWT
# verified against the OP's public JWKS plus the opaque local session cookie bound to it
# (RpRequestAuthenticator). It never reads the OP store or the canonical actor.
#
# The shared role uses the local cell for Base APP and ORG RP-owned routes. Other shared
# routes cannot resolve OP authority while the Access query API is unavailable.
module RpCellLocalSession
  extend ActiveSupport::Concern

  # Public signing keys of each realm OP, cached per process (not request state): one fetch per
  # issuer per OidcOpJwksClient::CACHE_TTL instead of one per request.
  private

  def rp_cell_process?
    role = RuntimeRole.current
    return true if RuntimeRole::RP_ROLES.include?(role)
    return false unless RuntimeRole.shared?(role)
    return false unless controller_path.start_with?("base/app/", "base/org/")

    %w(rp-base-app-ww rp-base-org-ww).include?(RuntimeRole.route_owner(controller_path))
  end

  def rp_cell
    RpCellBinding.for_client(rp_cell_client_id)
  end

  def rp_cell_issuer
    OidcIssuer.for_resource_type(rp_cell_resource_type)
  end

  def rp_cell_jwks_client
    OidcOpJwksClient.for_resource_type(rp_cell_resource_type)
  end

  def authenticate_rp_cell_request(access_token:)
    RpRequestAuthenticator.call(
      cell: rp_cell, access_token:,
      local_session_id: cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE],
      issuer: rp_cell_issuer, jwks_client: rp_cell_jwks_client,
    )
  end

  def clear_rp_cell_session_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
      OidcRpBrowserCredentialContract.session_cookie_deletion_options,
    )
  end
end
