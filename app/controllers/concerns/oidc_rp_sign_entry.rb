# typed: false
# frozen_string_literal: true

# The neutral entry renders on GET and starts OIDC only on the CSRF-protected POST.
module OidcRpSignEntry
  extend ActiveSupport::Concern

  include OidcSsoInitiator

  public

  def show
    response.set_header("Cache-Control", "no-store")
    render template: "shared/oidc_rp_sign_entries/show", layout: false
  end

  def create
    response.set_header("Cache-Control", "no-store")
    url = initiate_oidc_session!(target_link_uri: params[:target_link_uri])
    redirect_to_oidc_authorization_url(url, status: :see_other)
  end

  private

  def browser_rp_invalid_credentials_are_ignored?
    true
  end

  def reject_authenticated_rp_start!
    return unless logged_in?

    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
           content_type: "text/plain"
  end

  def neutral_sign_form_url
    url_for(only_path: true, ri: RequestContextContract.normalize_region(params[:ri]))
  end

  def neutral_sign_target_link_uri
    RpTargetLinkUri.normalize(params[:target_link_uri])
  end
end
