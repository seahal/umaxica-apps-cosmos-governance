# typed: false
# frozen_string_literal: true

module Base
  module Org
    class ApplicationController < ActionController::Base
      include ::OrgSecondPasskeyGate
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification

      include ::Session

      include ::PreferenceGlobal
      include ::BasePreferenceActorProjection

      include ::BrowserRpAuthentication
      include ::BrowserRpUnsafeRequestGuard
      include ::BaseRpSignInRedirect
      include ::AuthenticationWithdrawalGate

      include ::BaseAdmissionBrowserBinding
      include ::SignErrorResponses
      include ::AuthorizationAudit
      include ::AuthorizationOperator
      include ::VerificationOperator
      include ActionPolicy::Controller
      include ::ActorSupport
      include ::Finisher

      PREFERENCE_WRITE_CONTEXT = {
        surface_key: "base/org",
        realm: "org",
        preference_model: OrgPreference,
        issuer_id: "preference_org",
      }.freeze

      AUTHENTICATION_MODE = :deny_all

      prepend_before_action :enforce_fqdn_availability!

      after_action :verify_private_action_authorized!
      after_action :apply_authenticated_page_cache_policy!
      helper_method :current_resource, :browser_rp_authenticated?,
                    :current_browser_session_security_context, :current_session_public_id,
                    :current_session, :logged_in?
      prepend_before_action :guard_browser_rp_unsafe_request!

      layout "base/org/application"

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from BaseZenithIdentityResolver::DependencyUnavailable, with: :render_base_zenith_identity_unavailable
      rescue_from ::Oidc::AcmeServiceOrigin::ConfigurationUnavailable, with: :render_oidc_authority_unavailable
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_session_public_id,
                    :current_operator, :logged_in?

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
        scope: "base_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region

      before_action :enforce_withdrawal_gate!
      before_action :set_current_actor
      before_action :hydrate_base_preference_actor_state

      before_action :enforce_second_passkey_gate!, unless: :unavailable_authenticated_rp_root_feature
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_verification_if_required, unless: :unavailable_authenticated_rp_root_feature
      before_action :enforce_access_policy!
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
        when RpBaseOrgSession
          BaseZenithIdentityResolver.call(access_state: state, surface: :org)
        else
          raise ActiveRecord::RecordNotFound, "Base ORG identity has no recognized session binding"
        end
      end

      private

      def refuse_root_token_feature_in_rp_cell!
        feature = unavailable_authenticated_rp_root_feature
        return unless feature

        browser_rp_access_state

        Rails.logger.info(
          JitLogEvent.format(
            "auth.rp_feature.refused", occurred_at: Time.current.utc.iso8601(3),
                                       request_id: request.request_id, controller: self.class.name, action: action_name,
                                       reason_code: "root_token_feature_unavailable", feature:,
          ),
        )
        response.set_header("Cache-Control", "private, no-store")
        render plain: I18n.t("auth.rp_feature_unavailable"), status: :service_unavailable
      end

      def resolve_rp_cell_access(access_token)
        state = super
        BaseZenithIdentityResolver.call(access_state: state, surface: :org) if state.status == :valid
        state
      rescue BaseZenithIdentityResolver::LoginBlocked
        @current_rp_authentication_payload = nil
        invalid_browser_rp_access
      end

      def unavailable_authenticated_rp_root_feature
        return @unavailable_authenticated_rp_root_feature if defined?(@unavailable_authenticated_rp_root_feature)

        state = browser_rp_access_state
        return @unavailable_authenticated_rp_root_feature = nil unless
          state.status == :valid && state.rp_session.is_a?(RpBaseOrgSession)

        @unavailable_authenticated_rp_root_feature =
          case controller_path
          when "base/org/identity/secret_credentials"
            "secret_management"
          when "base/org/identity/sessions"
            "session_management"
          when "base/org/identity/removals"
            "identity_removal"
          end
      end

      def step_up_challenge_layout = "base/org/application"

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end

      def preference_write_actor
        resource = preference_current_resource
        return unless resource

        raise ActiveRecord::RecordNotFound, "Base preference actor has the wrong type" unless
          resource.instance_of?(Operator)

        resource
      end

      def preference_write_context = PREFERENCE_WRITE_CONTEXT

      def render_base_zenith_identity_unavailable
        response.set_header("Cache-Control", "no-store")
        head :service_unavailable
      end

      def browser_rp_client_id
        "base-org-ww"
      end

      def browser_rp_resource_type
        "operator"
      end

      def oidc_client_id
        browser_rp_client_id
      end

      private

      def render_oidc_authority_unavailable
        response.set_header("Cache-Control", "no-store")
        render plain: I18n.t("errors.messages.temporarily_unavailable"), status: :service_unavailable,
               content_type: "text/plain"
      end

      def rp_cell_issuer
        rp_op_origin.origin
      end

      def rp_cell_jwks_client
        OidcOpJwksClient.for_jwks_uri(rp_op_jwks_uri)
      end

      def rp_client_id = oidc_client_id

      def rp_realm = rp_cell_binding.realm

      def rp_resource_type = browser_rp_resource_type

      def rp_log_surface = "base_org"

      def rp_cell_binding = RpCellBinding.fetch("rp_base_org")

      def rp_record_class = RpBaseOrgRecord

      def rp_session_class = RpBaseOrgSession

      def rp_notice_face = "org"

      def rp_op_jwks_uri = rp_op_origin.jwks_uri

      def rp_op_origin
        return @rp_op_origin if defined?(@rp_op_origin)

        host = Rails.configuration.x.boot_config.fetch(:hosts).visa_staff&.host
        local_host = ::Oidc::AcmeServiceOrigin.host_from(host)
        scheme = local_host&.end_with?(".localhost") ? (request.ssl? ? "https" : "http") : "https"
        @rp_op_origin = ::Oidc::AcmeServiceOrigin.from_configured_host(host, default_scheme: scheme)
      end

      def rp_default_landing_path = base_org_dashboard_path(ri: params[:ri])

      def rp_callback_path = base_org_oidc_callback_path

      def rp_interruption_path = base_org_sign_interruption_path(ri: params[:ri])

      def rp_sign_path(**) = base_org_sign_show_path(**)

      def rp_sign_out_path(**) = base_org_sign_out_path(**)

      def rp_sign_out_completion_path = base_org_sign_out_completion_path

      def rp_root_path(**) = base_org_root_path(**)

      def rp_sign_out_component = "base/org/sign_outs/edit"

      def rp_sign_out_completed_description = t("base.org.sign_out.completed_description")

      def rp_sign_out_unavailable_after_local_description = t("base.org.sign_out.unavailable_after_local_description")

      def account_navigation_sign_in_path(**) = base_org_sign_show_path(**)

      def account_navigation_sign_out_path(**) = new_base_org_sign_out_path(**)

      def actor_verification_path(**args)
        base_org_verification_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
