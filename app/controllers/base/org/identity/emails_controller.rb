# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class EmailsController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def index
          authorize!(OperatorEmail, to: :index?)
          @staff_emails = current_operator.staff_emails.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        private

        def index_page_props
          {
            title: t("controller.sign.app.setting.index.email"),
            back_link: { label: t("sign.org.settings.show.back"), href: base_org_identity_path(ri: params[:ri]) },
            columns: {
              value: t("activerecord.attributes.staff_email.address"),
              status: t("activerecord.attributes.staff_email.status"),
            },
            empty_message: t("sign.org.settings.email.index.empty"),
            entries: @staff_emails.map { |email| serialize_email(email) },
          }
        end

        def serialize_email(email)
          verified = [OperatorEmailStatus::ACTIVE, OperatorEmailStatus::VERIFIED]
            .include?(email.staff_email_status_id)
          {
            public_id: email.public_id,
            value: email.address,
            status: page_t("views.sign.org.settings.emails.index.#{verified ? "verified" : "unverified"}"),
          }
        end
      end
    end
  end
end
