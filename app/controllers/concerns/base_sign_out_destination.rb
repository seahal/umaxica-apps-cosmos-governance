# typed: false
# frozen_string_literal: true

module BaseSignOutDestination
  extend ActiveSupport::Concern

  # Required private hooks: rp_session_class, rp_root_path(**options), rp_sign_out_path(**options),
  # rp_sign_out_component, rp_sign_out_completed_description and
  # rp_sign_out_unavailable_after_local_description.

  private

  def sign_out_edit_page_props
    state = browser_rp_access_state
    return if performed?

    active = state.status == :valid && state.rp_session.instance_of?(rp_session_class) && state.rp_session.active?
    return if performed?

    {
      title: active ? t("sign.shared.sign_out.title") : t("sign.shared.sign_out.already_signed_out"),
      active:,
      description: active ? t("sign.shared.sign_out.confirm_description") :
        t("sign.shared.sign_out.already_signed_out"),
      form: active ? sign_out_confirmation_form : nil,
      home_link: { label: t("sign.shared.sign_out.home_link"), href: rp_root_path(ri: sign_out_region) },
    }
  end

  def sign_out_confirmation_form
    {
      action: rp_sign_out_path(ri: sign_out_region),
      submit: t("sign.shared.sign_out.button"),
      confirm_description: t("sign.shared.sign_out.confirm_description"),
    }
  end

  def render_oidc_rp_logout_completion
    render inertia: rp_sign_out_component,
           props: {
             title: t("sign.shared.sign_out.completed_title"),
             active: false,
             description: rp_sign_out_completed_description,
             form: nil,
             home_link: { label: t("sign.shared.sign_out.home_link"), href: rp_root_path(ri: sign_out_region) },
           },
           status: :ok,
           clear_history: true
  end

  def render_oidc_rp_logout_unavailable(after_local_commit:)
    description =
      after_local_commit ? rp_sign_out_unavailable_after_local_description :
           t("sign.shared.sign_out.unavailable_description")
    render inertia: rp_sign_out_component,
           props: {
             title: t("sign.shared.sign_out.unavailable_title"),
             active: false,
             description:,
             form: nil,
             home_link: { label: t("sign.shared.sign_out.home_link"), href: rp_root_path(ri: sign_out_region) },
           },
           status: :service_unavailable,
           clear_history: after_local_commit
  end

  def sign_out_region
    RequestContextContract.normalize_region(params[:ri])
  end
end
