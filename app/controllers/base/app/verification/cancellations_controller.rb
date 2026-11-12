# frozen_string_literal: true

module Base
  module App
    module Verification
      class CancellationsController < Base::App::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        public

        def show
          authorize!(current_client, to: :show?)
          raise AccessOpDataUnavailableError
        end

        def create
          authorize!(current_client, to: :show?)
          raise AccessOpDataUnavailableError
        end
      end
    end
  end
end
