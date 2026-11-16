# typed: false
# frozen_string_literal: true

module Base
  module Org
    # adr/operator-capability-authorization.md, Support. The landing page lists only the areas this
    # operator holds a capability for (decided by the owner, Base::Org::Api::V0::Support::AreasController).
    class SupportController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage
      include ::OrgOwnerPageRelay

      AUTHENTICATION_MODE = :private

      layout "base/org/inertia"
      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }

      declare_authentication_mode! :private

      public

      # R5-WU17: the operator's capabilities are read by the Support owner over HTTPS.
      def index
        relay_owner_page!
      end
    end
  end
end
