# frozen_string_literal: true

# Read-side scope and return-target parsing shared by the retained RP step-up entrypoints.
module BaseStepUpIntent
  include StepUpCeremonyLogging

  private

  def requested_step_up_scope(allowed_scopes)
    scope = params[:scope].to_s
    raise ActionController::BadRequest, "invalid scope" unless allowed_scopes.key?(scope)

    scope
  end

  def requested_step_up_return_to(scope:, allowed_scopes:)
    return_to = resolve_step_up_pt(params[:pt])
    raise ActionController::BadRequest, "invalid pt" if return_to.blank?
    raise ActionController::BadRequest, "scope mismatch" unless return_to.match?(allowed_scopes.fetch(scope))

    return_to
  end
end
