# typed: false
# frozen_string_literal: true

# Shared receiver checks for the Avatar authority API under /api/v0/avatar/:surface (R5-WU14,
# docs/architecture/avatar-authority-contract-proposal.md, approved 2026-10-17).
#
# Server-to-server from a Base Self-RP: the caller presents a fresh Governance token derived from
# its active local RP session. The owner re-resolves the real actor and the complete selected context
# from request identifiers. It matches that tuple against the actor's selectable candidates; the
# RP's selection is transport, never authority. Existing Avatar policy, ownership-period and
# membership checks then apply.
module AvatarAuthorityApiEndpoint
  extend ActiveSupport::Concern

  include ProblemDetailsRendering

  REALMS = {
    "app" => { surface: :app, client_id: "base-app-ww", resource_type: "client" },
    "org" => { surface: :org, client_id: "base-org-ww", resource_type: "operator" },
  }.freeze

  private

  attr_reader :avatar_actor, :avatar_root

  def avatar_realm
    case self.class::AVATAR_SURFACE
    when "app" then REALMS.fetch("app")
    when "org" then REALMS.fetch("org")
    else raise ArgumentError, "unsupported Avatar API surface"
    end
  end

  def authenticate_avatar_caller!
    response.headers["Cache-Control"] = "no-store"
    realm = avatar_realm
    verification = BaseApiAuthorityTokenVerifier.call(
      token: bearer_token,
      expected_client_id: realm.fetch(:client_id),
      expected_audience_resource_type: realm.fetch(:resource_type),
    )
    unless verification.authenticated?
      return render(json: { error: "invalid_token" }, status: :unauthorized)
    end

    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: verification.principal,
      rp_session: verification.session,
      payload: verification.authentication_payload,
      security_context: nil,
    )
    @avatar_actor = BaseZenithIdentityResolver.call(access_state:, surface: realm.fetch(:surface))
    @avatar_root = verification.session
  rescue AccessOpDataUnavailableError, BaseZenithIdentityResolver::DependencyUnavailable
    render_problem(:service_unavailable)
  rescue BaseZenithIdentityResolver::LoginBlocked, BaseZenithIdentityResolver::WithdrawalRequired
    render(json: { error: "forbidden" }, status: :forbidden)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "invalid_token" }, status: :unauthorized)
  end

  def bearer_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    return if scheme != "Bearer" || token.blank? || token.match?(/\s/)

    token
  end

  # Base APP and ORG selections are owned by their RP sessions. The owner treats every supplied
  # identifier as untrusted and resolves the complete tuple against this verified actor's real
  # candidates before installing it for the existing Avatar policies.
  def verify_avatar_persona!
    candidate = BaseSwitcherAuthority.new(
      surface: avatar_realm.fetch(:surface), principal: avatar_actor,
    ).candidate_for_public_ids(
      account_public_id: params[:persona],
      organization_public_id: params[:organization_public_id],
      organization_unit_public_id: params[:organization_unit_public_id],
      avatar_public_id: params[:avatar_public_id],
    )
    return render_forbidden unless candidate

    public_ids = candidate.fetch(:public)
    @avatar_switcher = BaseSwitcherAuthority.new(
      surface: avatar_realm.fetch(:surface), principal: avatar_actor, selection: public_ids,
    )
    Actor.install_context!(
      selection: Actor::SelectedContext.new(
        account_public_id: public_ids.fetch(:account_public_id),
        collective_public_id: public_ids.fetch(:organization_public_id),
        collective_unit_public_id: public_ids.fetch(:organization_unit_public_id),
        avatar_public_id: public_ids.fetch(:avatar_public_id),
      ),
    )
  end

  # The owner-side proof must come from Access before an authority mutation can start.
  def with_owner_step_up(_scope)
    raise AccessOpDataUnavailableError
  end

  # Read-only owner endpoints run on the read role, where SELECT FOR UPDATE is forbidden. They
  # keep the same owner-side proof check without locking because they do not authorize a mutation.
  def with_owner_step_up_read(scope, surface:)
    require_owner_step_up(scope, surface) { |evidence| yield evidence }
  end

  def current_step_up_evidence
    raise AccessOpDataUnavailableError
  end

  def current_resource = avatar_actor

  def current_session = avatar_root

  def avatar_switcher
    @avatar_switcher ||= BaseSwitcherAuthority.new(
      surface: avatar_realm.fetch(:surface), principal: avatar_actor, session: avatar_root,
    )
  end

  def render_forbidden = render(json: { error: "forbidden" }, status: :forbidden)

  # A denial at the locked write, distinct from a policy refusal, so the RP keeps its 403 answer.
  def render_owner_denied = render(json: { error: "owner_denied" }, status: :forbidden)

  def render_not_found = render(json: { error: "not_found" }, status: :not_found)

  def render_bad_request = render(json: { error: "bad_request" }, status: :bad_request)

  def require_owner_step_up(scope, _surface)
    evidence = current_step_up_evidence
    unless evidence
      render json: { error: "step_up_required", scope: }, status: :forbidden
      return
    end

    yield evidence if block_given?
    true
  end
end
