# typed: false
# frozen_string_literal: true

# A generic, read-only page for expected abnormal OIDC endings. It never displays server reason data.
# Required private hook: rp_sign_path(**options), supplied by the including controller.
module OidcRpSignInterruption
  extend ActiveSupport::Concern

  public

  def show
    response.set_header("Cache-Control", "no-store")
    render template: "shared/oidc_rp_sign_interruptions/show", layout: false
  end

  private

  def interruption_sign_path
    rp_sign_path(ri: RequestContextContract.normalize_region(params[:ri]))
  end

  def browser_rp_invalid_credentials_are_ignored?
    true
  end
end
