# typed: false
# frozen_string_literal: true

# Enforces the "current actor is in withdrawal lifecycle" gate: actors
# in `closing` / `suspended` / `terminated` / `deactivated` states are
# restricted to the withdrawal flow itself. Anything else gets a redirect (HTML) or a 403 with
# `WITHDRAWAL_REQUIRED` (JSON / non-HTML).
#
# Shared by retained Base and Tech request controllers so the withdrawal rule and allowlist remain
# explicit at the request boundary.
module AuthenticationWithdrawalGate
  extend ActiveSupport::Concern

  private

  def enforce_withdrawal_gate!
    return unless logged_in?
    return unless current_resource
    return unless withdrawal_restricted_resource?(current_resource)

    # Allowlist: withdrawal flow
    return if withdrawal_gate_allowlisted?

    # API/JSON: return 403 Forbidden
    if request.format.json? || !request.format.html?
      render json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden
      return
    end

    # HTML: redirect to the withdrawal lifecycle surface
    safe_redirect_to(withdrawal_gate_redirect_path, fallback: acme_withdrawal_gate_redirect_path, status: :found)
  end

  def withdrawal_gate_allowlisted?
    return true if withdrawal_controller_allowlisted?

    # Allowlist: health/assets (rarely needed but safe)
    return true if controller_path == "rails/health"

    false
  end

  def withdrawal_controller_allowlisted?
    case controller_path
    when "base/app/identity/withdrawals"
      %w(show new edit update create destroy).include?(action_name)
    when "base/org/identity/withdrawals"
      action_name == "show"
    else
      false
    end
  end

  def withdrawal_restricted_resource?(resource)
    return true if resource.respond_to?(:closing?) && resource.closing?
    return true if resource.respond_to?(:suspended?) && resource.suspended?
    return true if resource.respond_to?(:terminated?) && resource.terminated?

    resource.respond_to?(:deactivated?) && resource.deactivated?
  end

  def withdrawal_gate_redirect_path
    ri = params[AuthIoKeys::Params::RI]

    case withdrawal_gate_surface_family
    when "app" then edit_base_app_identity_withdrawal_path(ri: ri)
    when "org" then base_org_identity_withdrawal_path(ri: ri)
    else
      raise ArgumentError, "no withdrawal redirect path configured for controller_path=#{controller_path}"
    end
  end

  # Derives the app/org family from a retained controller path. Unknown families raise instead of
  # crossing request ownership by guessing a destination.
  def withdrawal_gate_surface_family
    controller_path.split("/")[1]
  end

  def acme_withdrawal_gate_redirect_path
    edit_base_app_identity_withdrawal_path(ri: params[AuthIoKeys::Params::RI])
  end
end
