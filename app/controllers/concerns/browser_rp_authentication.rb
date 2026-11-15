# typed: false
# frozen_string_literal: true

# Shared Browser RP authentication. It authenticates only the RP access cookie
# and follows its sid to one verified RP Session, the owning Browser Session,
# and that session's current root token. The root chain is live security
# context, never a fallback credential when the RP cookie is absent.
module BrowserRpAuthentication
  extend ActiveSupport::Concern

  include RpCellLocalSession

  AccessState = Data.define(:status, :resource, :rp_session, :payload, :security_context)
  AUTHENTICATION_MODE_RULES = Concurrent::Map.new
  BASE_RP_CLIENT_IDS = %w(base-app-ww base-org-ww).freeze
  AUTHENTICATION_REQUIRED_REASONS = {
    missing: "access_credential_missing",
    invalid: "access_credential_invalid",
    withdrawal_required: "withdrawal_required",
  }.freeze
  private_constant :AUTHENTICATION_REQUIRED_REASONS

  class InvalidPolicyError < StandardError; end

  class MissingPolicyError < StandardError; end

  class SkipNotAllowedError < StandardError; end

  class_methods do
    def authentication_mode_rules
      AUTHENTICATION_MODE_RULES.fetch_or_store(self) { [] }
    end

    def local_authentication_mode_rules
      authentication_mode_rules
    end

    def declare_authentication_mode!(mode, only: nil, except: nil, **options)
      mode = mode.to_sym
      unless %i(bare deny_all guest private open).include?(mode)
        raise InvalidPolicyError, "Invalid authentication mode: #{mode.inspect}"
      end

      rule = {
        mode: mode,
        only: Array(only).map(&:to_s).presence,
        except: Array(except).map(&:to_s).presence,
        options: options,
      }
      AUTHENTICATION_MODE_RULES[self] = authentication_mode_rules + [rule]
    end

    def authentication_mode_for(action)
      action = action.to_s
      authentication_mode_rules.reverse_each do |rule|
        next if rule[:only].present? && rule[:only].exclude?(action)
        next if rule[:except].present? && rule[:except].include?(action)

        return rule[:mode]
      end

      return const_get(:AUTHENTICATION_MODE, false) if const_defined?(:AUTHENTICATION_MODE, false)

      :deny_all
    end

    def skip_before_action(*filters, **options)
      flattened = filters.flatten
      action_names =
        flattened.filter_map do |filter|
          next unless filter.respond_to?(:to_sym) && !filter.is_a?(Hash)

          filter.to_sym
        end
      if action_names.include?(:enforce_access_policy!)
        raise SkipNotAllowedError, "skip_before_action :enforce_access_policy! is prohibited (#{name})"
      end

      super
    end
  end

  public

  def current_resource
    browser_rp_access_state.resource
  end

  def current_client
    current_resource if browser_rp_resource_type.to_s == "client"
  end

  def current_operator
    current_resource if browser_rp_resource_type.to_s == "operator"
  end

  def logged_in?
    browser_rp_authenticated?
  end

  def authentication_credentials_invalid?
    browser_rp_access_state.status == :invalid
  end

  def verify_private_action_authorized!
    return unless self.class.authentication_mode_for(action_name) == :private

    verify_authorized
  end

  def apply_authenticated_page_cache_policy!
    return unless authenticated_page_response?
    return if response.headers["Cache-Control"].to_s.split(",").map(&:strip).include?("no-store")

    response.set_header("Cache-Control", "no-store")
  end

  def authenticated_page_response?
    return false unless response.media_type == "text/html" || response.headers["X-Inertia"] == "true"

    mode = self.class.authentication_mode_for(action_name)
    return true if mode == :private
    return false if mode == :bare

    logged_in?
  end

  def enforce_access_policy!
    mode = self.class.authentication_mode_for(action_name)
    case mode
    when :deny_all
      raise MissingPolicyError,
            # rubocop:disable I18n/RailsI18n/DecorateString -- This is a diagnostic exception, not customer copy.
            "Denied by default authentication mode for #{self.class.name}##{action_name}. " \
            "Declare a concrete authentication mode before exposing this endpoint."
    when :bare, :open
      # Ordinary credentials of a deactivated actor never open the withdrawal recovery pages; only
      # the withdrawal ceremony does. Every other open page renders anonymous.
      if browser_rp_access_state.status == :withdrawal_required && withdrawal_controller_allowlisted?
        return render_browser_rp_withdrawal_required!
      end
      return true unless authentication_credentials_invalid?

      clear_browser_rp_cookies!
      return true if browser_rp_invalid_credentials_are_ignored?

      render_browser_rp_invalid_credentials!
      false
    when :private
      authenticate_browser_rp!
    when :guest
      return true unless browser_rp_authenticated?

      render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
             content_type: "text/plain"
      false
    else
      raise InvalidPolicyError, "Unexpected authentication mode: #{mode.inspect}"
    end
  end

  # Guards shared with root-authenticated controllers branch on this instead of probing for
  # Browser RP methods.
  def browser_rp_controller? = true

  def browser_rp_authenticated?
    browser_rp_access_state.status == :valid
  end

  def authenticate_browser_rp!
    return true if browser_rp_authenticated?
    return false if browser_rp_dependency_failed?
    return render_browser_rp_withdrawal_required! if browser_rp_access_state.status == :withdrawal_required

    log_browser_rp_authentication_required!
    clear_browser_rp_cookies! if browser_rp_access_state.status == :invalid
    render_browser_rp_unauthenticated!
    false
  end

  def current_session_public_id
    current_browser_session_security_context&.root_session_public_id
  end

  def current_session
    current_browser_session_security_context&.root_token
  end

  def current_browser_session_security_context
    browser_rp_access_state.security_context
  end

  protected

  # Presence flags only: they separate an access credential the browser stopped sending from a
  # refused one, without recording either credential.
  def log_browser_rp_authentication_required!
    refused_status = @browser_rp_refused_access_status
    refused_status = browser_rp_access_state.status if refused_status.nil?
    Rails.logger.info(
      JitLogEvent.format(
        "auth.session.authentication_required",
        occurred_at: Time.current.utc.iso8601(3),
        request_id: request.request_id,
        controller: self.class.name,
        action: action_name,
        failure_reason: AUTHENTICATION_REQUIRED_REASONS.fetch(refused_status),
        access_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::ACCESS_COOKIE),
        refresh_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::REFRESH_COOKIE),
        # Strict credentials are withheld on a cross-site navigation; this tells that case apart.
        fetch_site: request.headers["Sec-Fetch-Site"].presence_in(%w(same-origin same-site cross-site none)),
      ),
    )
  end

  def browser_rp_client_id
    raise NotImplementedError, "controller must define browser_rp_client_id"
  end

  def browser_rp_resource_type
    raise NotImplementedError, "controller must define browser_rp_resource_type"
  end

  def token_class
    raise AccessOpDataUnavailableError
  end

  def browser_rp_trusted_origins
    []
  end

  # A refused credential on a public HTML page is detached and the page renders anonymous
  # (adr/invalid-browser-credential-recovery.md); other representations keep their
  # authentication failure response.
  def browser_rp_invalid_credentials_are_ignored?
    request.format.html?
  end

  def render_browser_rp_unauthenticated!
    response.set_header("Cache-Control", "no-store")
    return render(json: { error: "Unauthorized" }, status: :unauthorized) if request.format.json?

    render plain: I18n.t("errors.messages.login_required"), status: :unauthorized, content_type: "text/plain"
  end

  def render_browser_rp_invalid_credentials!
    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.login_required"), status: :unauthorized, content_type: "text/plain"
  end

  # Names the failed stage and an exception class or closed outcome; never a credential or message.
  def log_browser_rp_dependency_failure(stage:, detail:)
    Rails.logger.warn(
      JitLogEvent.format(
        "browser_rp.dependency.failed",
        request_id: request.request_id,
        stage: stage,
        detail: detail,
      ),
    )
  end

  def render_browser_rp_dependency_failure!
    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.temporarily_unavailable"), status: :service_unavailable,
           content_type: "text/plain"
  end

  def browser_rp_access_state
    return @browser_rp_access_state if defined?(@browser_rp_access_state)

    @browser_rp_access_state = resolve_browser_rp_access_cookie
  rescue ActiveRecord::ActiveRecordError, OidcOpJwksClient::FetchError, AccessOpDataUnavailableError,
         Oidc::AcmeServiceOrigin::ConfigurationUnavailable => e
    log_browser_rp_dependency_failure(stage: "access_state", detail: e.class.name)
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure! unless performed?
    @browser_rp_access_state = AccessState.new(
      status: :missing, resource: nil, rp_session: nil, payload: nil, security_context: nil,
    )
  end

  def browser_rp_dependency_failed?
    defined?(@browser_rp_dependency_failed) && @browser_rp_dependency_failed
  end

  def resolve_browser_rp_access_cookie(access_token: nil)
    return resolve_rp_cell_access(nil) if base_rp_cell_process?

    access_token ||= BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    return resolve_rp_cell_access(access_token) if rp_cell_process?

    if BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::SESSION_COOKIE).present?
      raise AccessOpDataUnavailableError
    end

    return AccessState.new(status: :missing, resource: nil, rp_session: nil, payload: nil, security_context: nil) if
      access_token.blank?

    raise AccessOpDataUnavailableError
  end

  # R5-WU17 cell process: the resource is the cell's local principal, the session its local session.
  def resolve_rp_cell_access(access_token)
    result =
      if base_rp_cell_process?
        BaseRpSessionAuthenticator.call(
          cell: rp_cell, local_session_id: cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE],
          issuer: rp_op_origin.origin,
        )
      else
        authenticate_rp_cell_request(access_token:)
      end
    return AccessState.new(
      status: result.status, resource: nil, rp_session: nil, payload: nil,
      security_context: nil,
    ) unless
      result.authenticated?

    @current_rp_authentication_payload = result.payload
    AccessState.new(
      status: :valid, resource: result.principal, rp_session: result.session, payload: result.payload,
      security_context: nil,
    )
  end

  def base_rp_cell_process?
    rp_cell_process? && BASE_RP_CLIENT_IDS.include?(rp_cell.client_id)
  end

  # Base APP and ORG selections are RP-local; other RP cells read their owner API.
  def rp_cell_selected_context
    return unless rp_cell_process?
    # Base APP and ORG selections belong to their RP sessions; no OP root token or remote
    # selection API participates.
    return Actor::SelectedContext::NULL unless browser_rp_authenticated? && rp_cell.client_id.start_with?("base-")

    if rp_cell.client_id == RpBaseAppSession::CLIENT_ID
      rp_session = browser_rp_access_state.rp_session
      return Actor::SelectedContext::NULL unless rp_session.instance_of?(RpBaseAppSession)

      selection =
        RpBaseAppRecord.connected_to(role: :writing) do
          RpBaseAppSessionSelection.find_by(rp_session_id: rp_session.id)
        end
      return Actor::SelectedContext::NULL unless selection

      return Actor::SelectedContext.new(
        account_public_id: selection.account_public_id,
        collective_public_id: selection.organization_public_id,
        collective_unit_public_id: selection.organization_unit_public_id,
        avatar_public_id: selection.avatar_public_id,
        selected_at: selection.selected_at,
      )
    end

    return rp_org_cell_selected_context if rp_cell.client_id == RpBaseOrgSession::CLIENT_ID

    result = OrgAdminAuthorityClient.new(
      rp_session: browser_rp_access_state.rp_session,
      browser_request: request, surface: rp_cell.realm,
    ).get("/identity/selection")
    return selected_context_from_owner(result.data) if result.ok?

    case result.status
    when :unauthorized
      if result.data.to_h["error"] == "invalid_token"
        @browser_rp_refused_access_status = :invalid
        clear_browser_rp_cookies!
        render_browser_rp_unauthenticated!
      else
        render_rp_owner_dependency_failure!(result.status)
      end
    when :forbidden
      head :forbidden
    when :bad_request, :not_found, :conflict, :gone, :unprocessable, :unavailable, :dependency
      render_rp_owner_dependency_failure!(result.status)
    else
      raise ArgumentError, "unsupported OP selection response status: #{result.status.inspect}"
    end

    Actor::SelectedContext::NULL
  end

  def rp_org_cell_selected_context
    rp_session = browser_rp_access_state.rp_session
    return Actor::SelectedContext::NULL unless rp_session.instance_of?(RpBaseOrgSession)

    selection =
      RpBaseOrgRecord.connected_to(role: :writing) do
        RpBaseOrgSessionSelection.includes(:avatar_selection).find_by(rp_session_id: rp_session.id)
      end
    return Actor::SelectedContext::NULL unless selection

    Actor::SelectedContext.new(
      account_public_id: selection.account_public_id,
      collective_public_id: selection.organization_public_id,
      collective_unit_public_id: selection.organization_unit_public_id,
      avatar_public_id: selection.avatar_selection&.avatar_public_id,
      selected_at: selection.selected_at,
    )
  end

  def selected_context_from_owner(data)
    Actor::SelectedContext.new(
      account_public_id: data["account_public_id"], collective_public_id: data["collective_public_id"],
      collective_unit_public_id: data["collective_unit_public_id"], avatar_public_id: data["avatar_public_id"],
      selected_at: data["selected_at"] && Time.zone.parse(data["selected_at"]),
    )
  end

  def render_rp_owner_dependency_failure!(status)
    log_browser_rp_dependency_failure(stage: "owner_selection", detail: status.to_s)
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure!
  end

  def rp_cell_client_id = browser_rp_client_id

  def rp_cell_resource_type = browser_rp_resource_type

  def invalid_browser_rp_access
    AccessState.new(status: :invalid, resource: nil, rp_session: nil, payload: nil, security_context: nil)
  end

  def withdrawal_required_browser_rp_access
    AccessState.new(
      status: :withdrawal_required, resource: nil, rp_session: nil, payload: nil, security_context: nil,
    )
  end

  # The same answers root authentication gives a deactivated actor: JSON 403, and on the app Base
  # surface an HTML redirect to that surface's withdrawal session entry.
  def render_browser_rp_withdrawal_required!
    response.set_header("Cache-Control", "no-store")
    if request.format.json?
      render json: { error: "WITHDRAWAL_REQUIRED", error_code: "withdrawal_required" }, status: :forbidden
      return false
    end

    # The withdrawal pages are the recovery ceremony's own; ordinary authentication never opens
    # them for a deactivated actor and never redirects from them
    # (test/security/invariants/withdrawal_gate_invariant_test.rb).
    if withdrawal_controller_allowlisted?
      head :unauthorized
      return false
    end

    ri = params[AuthIoKeys::Params::RI]
    entry_path =
      case controller_path.split("/").first(2)
      when %w(base app) then new_base_app_identity_withdrawal_session_path(ri: ri)
      end
    if entry_path
      redirect_to(entry_path, allow_other_host: false)
    else
      render plain: I18n.t("errors.messages.login_required"), status: :unauthorized, content_type: "text/plain"
    end
    false
  end

  def clear_browser_rp_access_cookie!
    cookie_name = OidcRpBrowserCredentialContract::ACCESS_COOKIE
    deletion_options = OidcRpBrowserCredentialContract.access_cookie_deletion_options
    cookies.delete(cookie_name, deletion_options)
    CredentialDeletionFinalizer.register(request.env, cookie_name, deletion_options)
    @current_rp_authentication_payload = nil
  end

  def clear_browser_rp_cookies!
    # Whenever the browser's RP credential is dropped, the signed-in pages are still in the
    # document's Inertia history; the next page must clear it.
    session[:inertia_clear_history] = true
    preserve_browser_rp_renewal_candidate! if @browser_rp_access_state&.status == :invalid
    clear_browser_rp_access_cookie!
    clear_rp_cell_session_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
    @browser_rp_access_state = AccessState.new(
      status: :missing,
      resource: nil,
      rp_session: nil,
      payload: nil,
      security_context: nil,
    )
  end

  def preserve_browser_rp_renewal_candidate!
  end
end
# rubocop:enable I18n/RailsI18n/DecorateString
