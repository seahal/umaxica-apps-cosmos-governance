# typed: false
# frozen_string_literal: true

# Builds the shared Inertia props that the React surface layout renders as page chrome.
#
# Before the Inertia migration this data was read straight out of the ERB layout by helpers
# (`current_banner_for`, `t(...)`, `*_url`). A React layout cannot reach any of that, so the chrome
# becomes a serialized prop shared by every Inertia response of the surface. Everything that is a
# server responsibility stays here: translation, route generation, the banner query, and the
# decision about which navigation a visitor is allowed to see.
# Base RP controllers provide account_navigation_sign_in_path(**options) and
# account_navigation_sign_out_path(**options); this concern does not select realm routes.
#
# The shared payload is per surface by construction: each including controller declares its own
# family, surface and banner domain, and `inertia_share` runs in that controller's instance, so one
# surface can never publish another surface's chrome.
module SurfaceChrome
  extend ActiveSupport::Concern

  # Query parameters that carry preference context across hosts. The cookie settings link has to
  # forward them or the destination loses the visitor's region and display preferences.
  PREFERENCE_QUERY_KEYS = %w(ri lx ct tz cu df tf mo dn ps).freeze

  # Base's banner domain selects the banner stream used by each browser surface.
  FAMILY_CHROME = {
    "base" => { family_label: "BASE", banner_domain: :acme },
  }.freeze
  ACCOUNT_NAVIGATION_SURFACES = [%w(base app), %w(base org)].freeze
  ACCOUNT_PROCEDURE_NAMESPACES = %w(sign sign_outs oidc).freeze
  ACCOUNT_NAVIGATION_EXCLUDED_CONTROLLER_PATHS = %w(
    base/app/preference/emails
    base/org/preference/emails
  ).freeze

  private

  def chrome_configuration
    @chrome_configuration ||=
      begin
        family, surface = controller_path.to_s.split("/").first(2)
        defaults =
          FAMILY_CHROME.fetch(family) do
            raise ArgumentError,
                  "#{self.class.name} renders Inertia pages from an unknown family #{family.inspect}; " \
                  "add its chrome to SurfaceChrome::FAMILY_CHROME rather than rendering chromeless pages"
          end

        defaults.merge(family: family, surface: surface).freeze
      end
  end

  def surface_chrome
    configuration = chrome_configuration

    chrome = {
      family_label: configuration.fetch(:family_label),
      surface: configuration.fetch(:surface),
      brand: chrome_brand,
      banner: chrome_banner(configuration.fetch(:banner_domain)),
      footer_navigation: nil,
      account_navigation: chrome_account_navigation,
      cookie_controls: chrome_cookie_controls,
      theme_controls: chrome_theme_controls,
      copyright: chrome_copyright,
    }
    chrome[:locale] = I18n.locale.to_s if configuration.fetch(:surface) == "com"
    chrome
  end

  def chrome_brand
    surface = chrome_configuration.fetch(:surface)
    href =
      case surface
      when "app" then base_app_root_path
      when "com" then base_com_root_path
      when "org" then base_org_root_path
      else raise ArgumentError, "unsupported Base chrome surface: #{surface.inspect}"
      end
    {
      name: ENV.fetch("BRAND_NAME"),
      href: href,
    }
  end

  # Whether the controls render, and where they send their reads and writes, is a family-and-surface
  # decision (PreferenceBrowserControlsRegistry). A pair the registry does not list raises rather than
  # rendering controls against a host that may not serve their endpoint.
  def chrome_preference_controls
    PreferenceBrowserControlsRegistry.fetch(
      family: chrome_configuration.fetch(:family),
      surface: chrome_configuration.fetch(:surface),
    )
  end

  # The banner query previously ran inside a layout partial on every response. It stays server-side
  # but moves out of the view, because a React layout cannot reach a Rails helper.
  def chrome_banner(domain)
    return nil if domain.blank?

    banner = CurrentBannerQuery.call(
      tld: chrome_configuration.fetch(:surface).to_sym,
      domain: domain,
      region: :global,
    )
    return nil if banner.blank?

    { title: banner.title.presence, body: banner.body }
  end

  def chrome_cookie_controls
    endpoint_path = chrome_preference_controls.cookie_endpoint_path
    surface = chrome_configuration.fetch(:surface)
    return nil if endpoint_path.nil?

    scope = "layouts.shared.footer_cookie_controls"
    # The cookie screen owns consent while it is being edited; showing the banner there would
    # put two controls for the same decision on one page.
    hidden = params[:action].to_s == "edit" &&
      (params[:preference_screen].to_s == "cookie" || controller_path.end_with?("/preference/cookies"))

    {
      hidden: hidden,
      scope: surface,
      endpoint_url: endpoint_path,
      settings_url: chrome_cookie_settings_url(surface),
      title: chrome_t("#{scope}.title"),
      description_html: chrome_t("#{scope}.description_html", privacy_policy: chrome_t("#{scope}.privacy_policy")),
      close_button: chrome_t("#{scope}.close_button"),
      reject_all: chrome_t("#{scope}.reject_all"),
      open_settings: chrome_t("#{scope}.open_settings"),
      accept_all: chrome_t("#{scope}.accept_all"),
    }
  end

  def chrome_cookie_settings_url(surface)
    # Query parameters arrive with string keys; url helpers merge default_url_options under
    # symbols. Passing the strings through as extra options duplicated `ri` on the href, which
    # is how the settings control pointed at a query the destination does not read as one value.
    options = request.query_parameters.slice(*PREFERENCE_QUERY_KEYS).symbolize_keys
    host =
      case surface
      when "app" then ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      when "com" then ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      when "org" then ENV.fetch("PUBLIC_BASE_STAFF_URL")
      else raise ArgumentError, "unsupported cookie preference surface: #{surface.inspect}"
      end
    options = options.merge(host: host)

    case surface
    when "app" then edit_base_app_preference_cookie_url(**options)
    when "com" then edit_base_com_preference_cookie_url(**options)
    when "org" then edit_base_org_preference_cookie_url(**options)
    else raise ArgumentError, "unsupported cookie preference surface: #{surface.inspect}"
    end
  end

  # The theme screen owns the theme control while it is being edited; showing the footer copy of it
  # there would put two controls for one value on the same page.
  def chrome_theme_controls
    endpoint_path = chrome_preference_controls.theme_endpoint_path
    return nil if endpoint_path.nil?

    scope = "layouts.shared.footer_theme_controls"
    hidden = params[:action].to_s == "edit" &&
      (params[:preference_screen].to_s == "theme" || controller_path.end_with?("/preference/themes"))

    {
      hidden: hidden,
      endpoint_url: endpoint_path,
      title: chrome_t("#{scope}.title"),
      description: chrome_t("#{scope}.description"),
      options: {
        system: chrome_t("#{scope}.options.system"),
        light: chrome_t("#{scope}.options.light"),
        dark: chrome_t("#{scope}.options.dark"),
      },
    }
  end

  def chrome_copyright
    "© #{Time.zone.today.year} #{ENV.fetch("BRAND_NAME")}"
  end

  def chrome_account_navigation
    family = chrome_configuration.fetch(:family)
    surface = chrome_configuration.fetch(:surface)
    return nil unless ACCOUNT_NAVIGATION_SURFACES.include?([family, surface])
    return nil if ACCOUNT_NAVIGATION_EXCLUDED_CONTROLLER_PATHS.include?(controller_path.to_s)
    return nil if ACCOUNT_PROCEDURE_NAMESPACES.include?(controller_path.split("/").third)

    signed_in = logged_in?

    options = request.query_parameters.slice(*PREFERENCE_QUERY_KEYS).symbolize_keys
    links =
      if signed_in
        [{
          label: chrome_t("layouts.shared.account_navigation.sign_out"),
          href: account_navigation_sign_out_path(**options),
        }]
      else
        [{
          label: chrome_t("layouts.shared.account_navigation.sign_up_or_in"),
          href: account_navigation_sign_in_path(**options),
        }]
      end
    {
      label: chrome_t("layouts.shared.account_navigation.label"),
      signed_in: signed_in,
      links:,
    }
  end

  # Keys are composed from the surface, so they cannot be literals at the call site; passing the
  # composed key through here keeps every translation lookup in one place.
  def chrome_t(key, **)
    t(key, **)
  end
end
