# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TelephonesController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        layout "base/app/inertia"
        inertia_share chrome: -> { surface_chrome }
        inertia_share clear_history: -> { session[:inertia_clear_history] == true }

        declare_authentication_mode! :private

        public

        def index
          authorize!(ClientTelephone, to: :index?)
          telephones = current_client.client_telephones.order(created_at: :asc)
          render inertia: true, props: telephones_index_props(telephones)
        end

        private

        def telephones_index_props(telephones)
          {
            title: "Telephones",
            empty_message: t("views.sign.app.settings.telephones.index.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            table_headings: {
              number: t("activerecord.attributes.user_telephone.number"),
              status: "Status",
            },
            telephones: telephones.map { |telephone| serialize_telephone(telephone) },
          }
        end

        def serialize_telephone(telephone)
          verified = [ClientTelephoneStatus::VERIFIED, ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP]
            .include?(telephone.user_telephone_status_id)
          {
            public_id: telephone.public_id,
            number: telephone.number.to_s,
            status_label: verified ?
              t("views.sign.app.settings.telephones.index.verified") :
              t("views.sign.app.settings.telephones.index.unverified"),
          }
        end
      end
    end
  end
end
