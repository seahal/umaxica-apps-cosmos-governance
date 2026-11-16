# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class ClosuresController < ActionController::API
        include ::DefaultNoStore
        include ::FqdnAvailabilityGate
        include ::RateLimit
        include ::RpBackchannelLogoutEndpoint

        AUTHENTICATION_MODE = :open

        prepend_before_action :enforce_fqdn_availability!
        ensure_fqdn_gate_first!
        prepend_before_action :apply_default_no_store
        rate_limit(
          to: 60,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "base_app_oidc_closures",
          name: "oidc_closures_ip",
          store: rate_limit_store,
          with: -> { head :too_many_requests },
        )

        public

        def create
          receive_rp_backchannel_logout!
        end

        private

        def rp_client_id = RpBaseAppSession::CLIENT_ID

        def rp_resource_type = "client"

        def rp_op_origin
          host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service&.host
          ::Oidc::AcmeServiceOrigin.from_configured_host(host, default_scheme: "https")
        end

        def rp_op_jwks_uri = rp_op_origin.jwks_uri

        def rp_cell_binding = RpCellBinding.fetch("rp_base_app")

        def rp_backchannel_logout_path = base_app_oidc_closures_path
      end
    end
  end
end
