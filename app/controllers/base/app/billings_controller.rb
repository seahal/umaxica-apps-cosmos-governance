# typed: false
# frozen_string_literal: true

module Base
  module App
    class BillingsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private

      layout "base/app/inertia"
      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }

      declare_authentication_mode! :private

      public

      def index
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Billings",
          description: t("billings.signed_in_required"),
          up_link: dashboard_up_link,
        }
      end
    end
  end
end
