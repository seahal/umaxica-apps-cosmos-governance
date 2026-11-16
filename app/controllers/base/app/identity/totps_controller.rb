# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TotpsController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        layout "base/app/inertia"
        inertia_share chrome: -> { surface_chrome }
        inertia_share clear_history: -> { session[:inertia_clear_history] == true }

        declare_authentication_mode! :private

        step_up only: :show, scope: "settings_totp"

        public

        def index
          authorize!(ClientTotpCredential, to: :index?)
          @totps = current_client.client_totp_credentials
            .where.not(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::DELETED)
            .order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def show
          find_totp
          authorize!(@totp)
          render inertia: true, props: show_page_props
        end

        private

        def step_up_requirement(scope:, **options)
          if scope == "settings_totp" && action_name == "show"
            credential = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
            return super(scope: scope, **options.merge(resource_ref: credential.public_id))
          end

          super
        end

        def find_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
        end

        def index_page_props
          {
            title: t("base.shared.identity.totps.title"),
            description: t("base.shared.identity.totps.description"),
            back_link: { label: t("base.shared.identity.up_link"), href: base_app_identity_path(ri: params[:ri]) },
            columns: {
              title: t("activerecord.attributes.user_totp_credential.title"),
              last_otp_at: t("activerecord.attributes.user_totp_credential.last_otp_at"),
              status: t("base.shared.identity.totps.status_label"),
            },
            empty_message: t("messages.no_totp_found"),
            totps: @totps.map { |totp| serialize_totp(totp) },
          }
        end

        def serialize_totp(totp)
          {
            public_id: totp.public_id,
            title: totp.title.presence || "-",
            last_otp_at: formatted_last_otp_at(totp),
            status: totp_status_label(totp),
            show_href: base_app_identity_totp_path(totp.public_id, ri: params[:ri]),
          }
        end

        def show_page_props
          {
            title: t("base.shared.identity.totps.show_title"),
            description: t("base.shared.identity.totps.show_description"),
            back_link: { label: t("actions.back"), href: base_app_identity_totps_path(ri: params[:ri]) },
            totp: {
              public_id: @totp.public_id,
              title: @totp.title,
              last_otp_at: formatted_last_otp_at(@totp),
              status: totp_status_label(@totp),
            },
          }
        end

        def totp_status_label(totp)
          case totp.user_identity_totp_credential_status_id
          when ClientTotpCredentialStatus::ACTIVE then t("base.shared.identity.totps.statuses.active")
          when ClientTotpCredentialStatus::INACTIVE then t("base.shared.identity.totps.statuses.inactive")
          when ClientTotpCredentialStatus::REVOKED then t("base.shared.identity.totps.statuses.revoked")
          when ClientTotpCredentialStatus::DELETED then t("base.shared.identity.totps.statuses.deleted")
          when ClientTotpCredentialStatus::NOTHING then t("base.shared.identity.totps.statuses.nothing")
          else raise ArgumentError, "unsupported TOTP credential status"
          end
        end

        def formatted_last_otp_at(totp)
          value = totp.last_otp_at
          usable = (value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)) && value > Time.zone.at(0)
          usable ? l(value, format: :short) : "-"
        end
      end
    end
  end
end
