# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        # POST /api/v0/tech-capability-checks (R5-WU11). Answers {"allowed": true|false} for the Tech
        # RP from current org-authority state; no browser session or cookie takes part.
        class TechCapabilityChecksController < ActionController::API
          include ::DefaultNoStore

          prepend_before_action :apply_default_no_store
          include ::RateLimit

          AUTHENTICATION_MODE = :open

          rescue_from AccessOpDataUnavailableError, with: :render_access_unavailable

          rate_limit(
            to: 120, within: 1.minute, by: -> { request.remote_ip }, scope: "base_org_tech_capability_check",
            name: "tech_capability_check_ip", store: rate_limit_store, only: :create,
            with: -> { head :too_many_requests },
          )

          public

          def create
            response.headers["Cache-Control"] = "no-store"
            decision = TechCapabilityCheckQuery.call(token: bearer_token)
            return render(json: { error: "invalid_token" }, status: :unauthorized) unless decision.authenticated?

            render json: { allowed: decision.allowed }, status: :ok
          end

          private

          def render_access_unavailable
            response.headers["Cache-Control"] = "no-store"
            render_problem(:service_unavailable)
          end

          def bearer_token
            scheme, token = request.authorization.to_s.split(" ", 2)
            return if scheme != "Bearer" || token.blank? || token.match?(/\s/)

            token
          end
        end
      end
    end
  end
end
