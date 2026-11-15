# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class EmailsController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        layout "base/app/inertia"
        inertia_share chrome: -> { surface_chrome }
        inertia_share clear_history: -> { session[:inertia_clear_history] == true }

        declare_authentication_mode! :private

        public

        def index
          authorize!(ClientEmail, to: :index?)
          emails = current_client.client_emails.order(created_at: :asc)
          render inertia: true, props: emails_index_props(emails)
        end

        private

        def emails_index_props(emails)
          {
            title: "Emails",
            empty_message: t("views.sign.app.settings.emails.index.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            table_headings: {
              address: t("activerecord.attributes.user_email.address"),
              status: "Status",
            },
            emails: emails.map { |email| serialize_email(email) },
          }
        end

        def serialize_email(email)
          verified = [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP]
            .include?(email.user_email_status_id)
          {
            public_id: email.public_id,
            address: email.address,
            status_label: verified ?
              t("views.sign.app.settings.emails.index.verified") : t("views.sign.app.settings.emails.index.unverified"),
          }
        end
      end
    end
  end
end
