# frozen_string_literal: true

module Base
  module Org
    module Verification
      class CancellationsController < Base::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        public

        def show
          authorize!(current_operator, to: :show?)
          raise AccessOpDataUnavailableError
        end

        def create
          authorize!(current_operator, to: :show?)
          raise AccessOpDataUnavailableError
        end
      end
    end
  end
end
