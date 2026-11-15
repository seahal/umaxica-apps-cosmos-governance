# typed: false
# frozen_string_literal: true

module Base
  module Org
    class WelcomesController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private

      layout "base/org/inertia"
      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }

      declare_authentication_mode! :private

      public

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: base_org_dashboard_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end
