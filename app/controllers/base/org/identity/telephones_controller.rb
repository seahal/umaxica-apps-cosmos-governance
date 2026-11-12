# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class TelephonesController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        public

        def index
          authorize!(OperatorTelephone, to: :index?)
          @staff_telephones = current_operator.staff_telephones.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        private

        def index_page_props
          {
            title: t("controller.sign.app.setting.index.telephone"),
            back_link: { label: t("sign.org.settings.show.back"), href: base_org_identity_path(ri: params[:ri]) },
            columns: {
              value: t("activerecord.attributes.staff_telephone.number"),
              status: t("activerecord.attributes.staff_telephone.status"),
            },
            empty_message: t("sign.org.settings.telephone.index.empty"),
            entries: @staff_telephones.map { |telephone| serialize_telephone(telephone) },
          }
        end

        def serialize_telephone(telephone)
          verified = [OperatorTelephoneStatus::ACTIVE, OperatorTelephoneStatus::VERIFIED]
            .include?(telephone.staff_telephone_status_id)
          {
            public_id: telephone.public_id,
            value: telephone.number,
            status: page_t("views.sign.org.settings.telephones.index.#{verified ? "verified" : "unverified"}"),
          }
        end
      end
    end
  end
end
