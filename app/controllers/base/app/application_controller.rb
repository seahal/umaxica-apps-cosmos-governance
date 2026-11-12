# typed: false
# frozen_string_literal: true

module Base
  module App
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification

      include ::Session

      include ::PreferenceGlobal
      include ::BasePreferenceActorProjection

      include ::BrowserRpAuthentication
      include ::BrowserRpUnsafeRequestGuard
      include ::AuthenticationWithdrawalGate

      include ::BaseAdmissionBrowserBinding
      include ::SignErrorResponses
      include ::AuthorizationAudit
      include ::AuthorizationClient
      include ::VerificationClient
      include ActionPolicy::Controller
      include SurfaceRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      PREFERENCE_WRITE_CONTEXT = {
        surface_key: "base/app",
        realm: "app",
        preference_model: AppPreference,
        issuer_id: "preference_app",
      }.freeze

      AUTHENTICATION_MODE = :deny_all
      after_action :verify_private_action_authorized!
      after_action :apply_authenticated_page_cache_policy!
      helper_method :current_resource, :browser_rp_authenticated?, :browser_rp_session_public_id,
                    :current_browser_session_security_context, :current_session_public_id,
                    :current_session, :logged_in?
      prepend_before_action :guard_browser_rp_unsafe_request!

      class << self
        public

        def base_admission_surface_name = "app"
      end

      layout "base/app/application"

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from BaseZenithIdentityResolver::DependencyUnavailable, with: :render_base_zenith_identity_unavailable
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id,
                    :current_client, :logged_in?, :active_client?, :logged_in_client?

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: explicit RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> effect reflection -> Verification -> AuthZ
      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "base_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      # Preference transport and request-local context must run before Actor hydration.
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region

      before_action :set_current_actor
      before_action :hydrate_base_preference_actor_state
      before_action :apply_localization_preferences
      # These side effects reflect Actor.preferences for the current request only.
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :enforce_verification_if_required, unless: :unavailable_authenticated_rp_root_feature
      before_action :enforce_access_policy!
      before_action :refuse_unavailable_rp_root_feature!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # Rails validates Origin and Fetch Metadata first; require its session-bound token before surface callbacks.
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      protect_from_forgery using: :header_or_legacy_token, with: :exception, prepend: true
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store

      public

      def current_resource
        state = browser_rp_access_state
        return unless state.status == :valid

        case state.rp_session
        when RpBaseAppSession
          BaseZenithIdentityResolver.call(access_state: state, surface: :app)
        else
          raise ActiveRecord::RecordNotFound, "Base APP identity has no recognized session binding"
        end
      end

      private

      def resolve_rp_cell_access(access_token)
        state = super
        BaseZenithIdentityResolver.call(access_state: state, surface: :app) if state.status == :valid
        state
      rescue BaseZenithIdentityResolver::WithdrawalRequired
        @current_access_token_payload = nil
        withdrawal_required_browser_rp_access
      rescue BaseZenithIdentityResolver::LoginBlocked
        @current_access_token_payload = nil
        invalid_browser_rp_access
      end

      def refuse_unavailable_rp_root_feature!
        feature = unavailable_authenticated_rp_root_feature
        return unless feature

        Rails.logger.info(
          JitLogEvent.format(
            "auth.rp_feature.refused", reason_code: "rp_root_session_unavailable", feature: feature,
                                       surface: "base_app", request_id: request.request_id,
          ),
        )
        response.set_header("Cache-Control", "private, no-store")
        render plain: t("auth.rp_feature_unavailable"), status: :service_unavailable
      end

      def unavailable_authenticated_rp_root_feature
        return @unavailable_authenticated_rp_root_feature if defined?(@unavailable_authenticated_rp_root_feature)

        state = browser_rp_access_state
        return @unavailable_authenticated_rp_root_feature = nil unless
          state.status == :valid && state.rp_session.is_a?(RpBaseAppSession)

        @unavailable_authenticated_rp_root_feature = unavailable_rp_root_feature
      end

      def unavailable_rp_root_feature
        case controller_path
        when "base/app/secrets", "base/app/secret_issuances", "base/app/secret_presentations"
          "secret_management"
        when "base/app/identity/sessions"
          "session_management"
        when "base/app/verifications", "base/app/verification/setups"
          "secret_verification" if secret_verification_request?
        end
      end

      def secret_verification_request?
        return true if params[:scope] == "settings_secret_credential"
        return false unless params[:scope] == "settings_passkey"

        target = params[:return_target]
        target = resolve_step_up_pt(params[:pt]) if target.nil?
        target.is_a?(String) && %r{\A/secret_issuances(?:/|\?|\z)}.match?(target)
      end

      def step_up_challenge_layout = "base/app/application"

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end

      def current_verification_actor
        current_client
      end

      def preference_write_actor
        resource = preference_current_resource
        return unless resource

        raise ActiveRecord::RecordNotFound, "Base preference actor has the wrong type" unless
          resource.instance_of?(Client)

        resource
      end

      def preference_write_context = PREFERENCE_WRITE_CONTEXT

      def render_base_zenith_identity_unavailable
        response.set_header("Cache-Control", "no-store")
        head :service_unavailable
      end

      def browser_rp_client_id
        "base-app-ww"
      end

      def browser_rp_resource_type
        "client"
      end

      def oidc_client_id
        browser_rp_client_id
      end

      private

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end

      # Base collects consent and issues the scoped admission before leaving its root session.
      def actor_verification_setup_path(**args)
        base_app_verification_setup_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
