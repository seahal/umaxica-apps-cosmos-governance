# typed: false
# frozen_string_literal: true

module RpBackchannelLogoutEndpoint
  extend ActiveSupport::Concern

  include OidcRpRoutePath

  # Required private hooks: rp_client_id, rp_resource_type, rp_op_origin, rp_op_jwks_uri,
  # rp_cell_binding and rp_backchannel_logout_path.

  private

  def receive_rp_backchannel_logout!
    return head :not_found unless registered_rp_request_host?

    verification = OidcOpLogoutTokenVerifier.new(
      logout_token: params[:logout_token].to_s,
      client_id: rp_client_id,
      issuer: rp_op_origin.origin,
      jwks_client: OidcOpJwksClient.for_jwks_uri(rp_op_jwks_uri),
    ).call
    return head :service_unavailable if verification.key_unavailable?
    return head :bad_request unless verification.success?

    RpCellSessionRevoker.call(cell: rp_cell_binding, payload: verification.payload)
    head :ok
  rescue RpCellSessionRevoker::EventConflict
    head :conflict
  rescue Oidc::AcmeServiceOrigin::ConfigurationUnavailable, OidcOpJwksClient::FetchError,
         Umaxica::Valkey::Error, ActiveRecord::ActiveRecordError, PG::Error, Faraday::Error,
         OutboundHttp::Connection::InsecureEndpointError
    head :service_unavailable
  end

  def registered_rp_request_host?
    return false unless request.path == rp_local_route_path(rp_backchannel_logout_path)

    registered_uris = OidcClientRegistry.find!(rp_client_id)
      .redirect_uris_by_realm.fetch(rp_resource_type)
    registered_uris.any? do |registered_uri|
      uri = URI.parse(registered_uri)
      uri.host == request.host && uri.port == request.port && uri.scheme == request.protocol.delete_suffix("://")
    end
  rescue OidcClientRegistry::ClientNotFound, URI::InvalidURIError, KeyError
    false
  end
end
