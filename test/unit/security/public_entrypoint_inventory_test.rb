# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class PublicEntrypointInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    APP_CONTROLLER_PREFIXES = %w(base tech).freeze

    APPLICATION_CLASS_PREFIXES = %w(Base:: Tech::).freeze

    PUBLIC_MODES = %i(bare open guest).freeze
    PRIVATE_MODES = %i(private deny_all).freeze

    DOCUMENT_PATH = Rails.root.join("docs/security/public-entrypoints.md")
    DOCUMENTED_CATEGORY_IDS = %w(
      PUBLIC_ROOTS
      PUBLIC_DASHBOARD
      PUBLIC_HEALTH
      PUBLIC_REVISION
      PUBLIC_CSP_REPORTS
      PUBLIC_WELL_KNOWN
      PUBLIC_ROBOTS_SITEMAPS
      PUBLIC_PWA_OFFLINE
      PUBLIC_PREFERENCE
      PUBLIC_WITHDRAWAL
      PUBLIC_BASE_OWNER_API
    ).freeze

    BASE_OWNER_API_PATH = %r{
      \A/api/v0/(avatar|membership|iam|support|identity/(?:standing|selection)|tech-capability-checks)\b
    }x

    RouteEntry = Struct.new(:verb, :path, :controller_path, :action, :controller_class, :mode, keyword_init: true)

    test "public entrypoint documentation names every enforced category" do
      content = File.read(DOCUMENT_PATH)

      DOCUMENTED_CATEGORY_IDS.each do |category_id|
        assert_includes content, "`#{category_id}`"
      end
    end

    test "application routes resolve to locally declared authentication modes" do
      missing =
        application_route_entries.filter_map do |entry|
          next if local_authentication_declaration?(entry.controller_class)

          "#{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty missing, "Application routes must declare authentication mode locally:\n#{missing.join("\n")}"
    end

    test "public application routes are covered by the documented public categories" do
      undocumented =
        application_route_entries.filter_map do |entry|
          next unless PUBLIC_MODES.include?(entry.mode)
          next if documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty undocumented, "Public routes need a documented category:\n#{undocumented.join("\n")}"
    end

    test "private and deny-all routes are not public entrypoints" do
      wrongly_public =
        application_route_entries.filter_map do |entry|
          next unless PRIVATE_MODES.include?(entry.mode)
          next unless documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty wrongly_public, "Private routes must not match public categories:\n#{wrongly_public.join("\n")}"
    end

    test "PUBLIC_PWA_OFFLINE covers exactly the two Rails PWA endpoints" do
      # Rails::PwaController is a framework controller, so these routes are outside
      # application_route_entries by construction. They are still public entrypoints, so the category
      # is enforced here instead. See adr/pwa-offline-route-exception.md.
      entries =
        Rails.application.routes.routes.filter_map do |route|
          controller_path = route.defaults[:controller].to_s
          next unless controller_path == "rails/pwa"

          [route.verb, route.path.spec.to_s.sub(/\(\.:format\)\z/, ""), route.defaults[:action].to_s]
        end

      # Governance draws only Base's three realms, each with the two framework PWA endpoints.
      assert_equal 6, entries.size, "expected two PWA endpoints on each Base realm host"
      assert_equal ["GET"], entries.map(&:first).uniq
      assert_equal(
        [["/offline", "offline"], ["/service-worker", "service_worker"]],
        entries.map { |entry| entry.drop(1) }.uniq.sort,
      )
    end

    private

    def application_route_entries
      Rails.application.routes.routes.filter_map do |route|
        controller_path = route.defaults[:controller].to_s
        action = route.defaults[:action].to_s
        next if controller_path.blank? || action.blank?
        next unless application_controller_path?(controller_path)

        controller_class = "#{controller_path.camelize}Controller".safe_constantize
        mode = authentication_mode(controller_class, action)

        RouteEntry.new(
          verb: route.verb.presence || "ANY",
          path: route.path.spec.to_s.sub(/\(\.:format\)\z/, ""),
          controller_path: controller_path,
          action: action,
          controller_class: controller_class,
          mode: mode,
        )
      end
    end

    def application_controller_path?(controller_path)
      APP_CONTROLLER_PREFIXES.any? { |prefix| controller_path.start_with?("#{prefix}/") }
    end

    def authentication_mode(controller_class, action)
      flunk("Missing controller class for application route") if controller_class.blank?
      flunk("Unexpected controller class #{controller_class.name}") unless
        application_controller_class?(controller_class)

      if controller_class.respond_to?(:authentication_mode_for)
        controller_class.authentication_mode_for(action)
      elsif controller_class.const_defined?(:AUTHENTICATION_MODE, false)
        controller_class.const_get(:AUTHENTICATION_MODE, false)
      else
        flunk("#{controller_class.name} does not expose authentication mode metadata")
      end
    end

    def application_controller_class?(controller_class)
      controller_class.name.start_with?(*APPLICATION_CLASS_PREFIXES)
    end

    def local_authentication_declaration?(controller_class)
      controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
        (controller_class.respond_to?(:local_authentication_mode_rules) &&
          controller_class.local_authentication_mode_rules.present?)
    end

    def documented_public_category(entry)
      return false unless PUBLIC_MODES.include?(entry.mode)

      public_root?(entry) ||
        public_dashboard?(entry) ||
        public_health?(entry) ||
        public_revision?(entry) ||
        public_csp_report?(entry) ||
        public_well_known?(entry) ||
        public_robots_or_sitemap?(entry) ||
        public_preference?(entry) ||
        public_withdrawal?(entry) ||
        public_base_owner_api?(entry)
    end

    def public_base_owner_api?(entry)
      entry.controller_path.match?(%r{\Abase/(app|com|org)/api/v0/}) &&
        entry.path.match?(BASE_OWNER_API_PATH)
    end

    def public_root?(entry) = get?(entry) && entry.path == "/"

    def public_dashboard?(entry)
      get?(entry) && entry.path == "/dashboard" && entry.action == "show" &&
        entry.controller_path.match?(%r{\Abase/(app|org)/roots\z})
    end

    def public_health?(entry)
      get?(entry) && (entry.path.start_with?("/health") || entry.path == "/api/v0/health.json")
    end

    def public_revision?(entry)
      get?(entry) && ["/revision", "/api/v0/revision.json"].include?(entry.path)
    end

    def public_csp_report?(entry) = post?(entry) && entry.path == "/csp-violation-report"

    def public_well_known?(entry) = get?(entry) && entry.path.start_with?("/.well-known/")

    def public_robots_or_sitemap?(entry) = get?(entry) && ["/robots.txt", "/sitemap.xml"].include?(entry.path)

    def public_preference?(entry)
      entry.path.start_with?("/preference") || entry.path.start_with?("/api/v0/preferences")
    end

    def public_withdrawal?(entry)
      (entry.path.start_with?("/identity/withdrawal") &&
        entry.controller_path.match?(%r{\Abase/app/identity/withdrawal(?:s|/sessions)\z})) ||
        (entry.path.start_with?("/identity/privacy/erasure") &&
          entry.controller_path.match?(%r{\Abase/app/identity/privacy/erasure(?:s|/statuses)\z}))
    end

    def get?(entry) = route_allows?(entry, "GET")

    def post?(entry) = route_allows?(entry, "POST")

    def route_allows?(entry, verb)
      entry.verb.split("|").include?(verb)
    end
  end
end
