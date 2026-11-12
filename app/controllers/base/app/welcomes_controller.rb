# typed: false
# frozen_string_literal: true

module Base
  module App
    class WelcomesController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Welcome!",
          next_link: {
            label: "Next",
            href: base_app_dashboard_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end
