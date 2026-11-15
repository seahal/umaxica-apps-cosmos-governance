# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oidc
      class CallbacksController < Base::Org::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false
      end
    end
  end
end
