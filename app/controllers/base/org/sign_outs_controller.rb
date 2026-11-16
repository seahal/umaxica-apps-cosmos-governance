# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SignOutsController < Base::Org::ApplicationController
      include ::SignOutNotice
      include ::OidcRpLogoutLauncher
      include ::BaseSignOutDestination
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      layout "base/org/inertia"
      inertia_share chrome: -> { surface_chrome }
      declare_authentication_mode! :open
      prepend_before_action :apply_default_no_store
      before_action :authenticate_oidc_rp_session!, only: :create
      after_action :sign_out_notice_cache_headers!, only: %i(show edit create)

      public

      def show
        complete_oidc_rp_logout!
      end

      def new
        redirect_to(
          edit_base_org_sign_out_path(ri: RequestContextContract.normalize_region(params[:ri])),
          status: :see_other,
        )
      end

      def edit
        props = sign_out_edit_page_props
        return if performed?

        render inertia: "base/org/sign_outs/edit", props:
      rescue ActiveRecord::ActiveRecordError, PG::Error => e
        log_sign_out_failure("confirmation_page", e)
        render_oidc_rp_logout_unavailable(after_local_commit: false)
      end

      def create
        launch_oidc_rp_logout!
      end
    end
  end
end
