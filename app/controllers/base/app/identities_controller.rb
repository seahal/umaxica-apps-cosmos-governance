# typed: false
# frozen_string_literal: true

module Base
  module App
    class IdentitiesController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          up_link: dashboard_up_link(label: t("base.shared.identity.up_link")),
          sections: identity_hub_sections,
        }
      end

      private

      def identity_hub_sections
        [
          identity_profile_section,
          identity_security_section,
          identity_account_section,
        ]
      end

      def identity_profile_section
        {
          heading: t("base.shared.identity.sections.profile"),
          items: [
            identity_hub_link(:emails, base_app_identity_emails_path(ri: params[:ri])),
            identity_hub_link(:telephones, base_app_identity_telephones_path(ri: params[:ri])),
            identity_hub_link(:birthdate, base_app_identity_birthdate_path(ri: params[:ri])),
          ],
        }
      end

      def identity_security_section
        {
          heading: t("base.shared.identity.sections.security"),
          items: [
            identity_hub_link(:passkey, base_app_identity_passkeys_path(ri: params[:ri])),
            identity_hub_link(:totp, base_app_identity_totps_path(ri: params[:ri])),
            identity_hub_link(:activities, base_app_identity_activities_path(ri: params[:ri])),
            identity_hub_link(:standing, base_app_identity_standing_path(ri: params[:ri])),
          ],
        }
      end

      def identity_account_section
        {
          heading: t("base.shared.identity.sections.account"),
          items: [
            identity_hub_link(:withdrawal, new_base_app_identity_withdrawal_path(ri: params[:ri])),
          ],
        }
      end

      def identity_hub_link(key, href)
        { label: t(key, scope: "base.shared.identity.links"), href: href }
      end
    end
  end
end
