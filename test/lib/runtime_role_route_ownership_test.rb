# frozen_string_literal: true

require "test_helper"

# R5-WU17 role ingress boundary: every routed controller has exactly one owning runtime role, and a
# role process serves only its own controllers.
class RuntimeRoleRouteOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Framework engines are not application surfaces; a role process does not serve them. The
  # inertia_rails DevTools routes are drawn in every environment but only match in development;
  # the test below shows they are unreachable here.
  FRAMEWORK_PREFIXES = %w(rails/ inertia_rails/devtools/).freeze

  test "inertia_rails DevTools routes are unreachable outside development" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/_inertia/devtools/entries")
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/_inertia/devtools/entries/1")
    end
  end

  test "every routed application controller has an owning role" do
    unowned =
      routed_controllers.reject { |path| path.start_with?(*FRAMEWORK_PREFIXES) }.filter_map do |path|
        RuntimeRole.route_owner(path)
        nil
      rescue RuntimeRole::UnownedRoute
        path
      end

    assert_empty unowned
  end

  test "every owning role is a known runtime role" do
    owners =
      routed_controllers.reject { |path| path.start_with?(*FRAMEWORK_PREFIXES) }.map do |path|
        RuntimeRole.route_owner(path)
      end.uniq - [RuntimeRole::ANY_ROLE]

    assert_empty owners - RuntimeRole::ALL
  end

  test "Base identity and credential pages belong to the realm RP" do
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/identity/birthdates")
    assert_equal RuntimeRole::ANY_ROLE, RuntimeRole.route_owner("base/com/roots")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/identity/secret_credentials")
  end

  test "retained Base app and org pages belong to their RP cell" do
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/roots")
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/sign/entries")
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/oidc/callbacks")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/sign/entries")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/oidc/callbacks")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/oidc/closures")
    assert_equal RuntimeRole::ANY_ROLE, RuntimeRole.route_owner("base/com/preferences")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/verification/completions")
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/avatars")
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/actor_support")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/actor_support")
  end

  test "domain owner APIs belong to their domain authority" do
    assert_equal "domain-avatar", RuntimeRole.route_owner("base/app/api/v0/avatar/avatars")
    assert_equal "domain-org", RuntimeRole.route_owner("base/org/api/v0/support/accounts")
    assert_raises(RuntimeRole::UnownedRoute) do
      RuntimeRole.route_owner("base/org/api/v0/publishing/entries")
    end
  end

  test "retained RP surfaces map to their own cell" do
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/roots")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/roots")
    assert_equal "rp-tech-org-ww", RuntimeRole.route_owner("tech/org/roots")
    assert_equal RuntimeRole::ANY_ROLE, RuntimeRole.route_owner("mission/jobs")
  end

  test "a prefix matches whole path segments only" do
    # `identities` is its own entry; `identityx` shares the characters of `identity` but no segment.
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/identities")
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("base/app/identityx") }
  end

  test "an unknown family or empty path is unowned" do
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("unknown/app/roots") }
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("") }
  end

  test "a role serves its own controllers and shared paths, and nothing else" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"

    assert RuntimeRole.serves?("base/app/roots", "rp-base-app-ww")
    assert RuntimeRole.serves?("base/org/sign/entries", "rp-base-org-ww")
    assert RuntimeRole.serves?("base/app/healths", "rp-tech-org-ww")
    assert_not RuntimeRole.serves?("base/org/roots", "rp-base-app-ww")
    assert RuntimeRole.serves?("base/app/identity/birthdates", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/avatars", "op-base-app")
    assert_not RuntimeRole.serves?("unknown/app/roots", "op-base-app")
  end

  test "a closed RP cell serves only health and revision" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "closed"

    assert RuntimeRole.serves?("base/app/healths", "rp-base-app-ww")
    assert RuntimeRole.serves?("base/app/revisions", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/oidc/closures", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/avatars", "rp-base-app-ww")
  end

  test "RP cells keep only the repository JWT signing keyset" do
    assert_equal ["AUTH_JWT_PRIVATE_KEYSET"], RuntimeRole.rp_private_env_names("rp-tech-org-ww")
  end

  test "RP cell roles resolve to their exact database connections" do
    assert_equal "rp_base_app", RuntimeRole.cell_connection("rp-base-app-ww")
    assert_equal "rp_base_org", RuntimeRole.cell_connection("rp-base-org-ww")
    assert_equal "rp_tech_org", RuntimeRole.cell_connection("rp-tech-org-ww")
    assert_raises(RuntimeRole::UnknownRole) { RuntimeRole.cell_connection(RuntimeRole::SHARED) }
  end

  test "an RP cell refuses to guess its browser admission" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "ajar"

    assert_raises(RuntimeRole::UnknownRole) { RuntimeRole.serves?("base/app/roots", "rp-base-app-ww") }
    ENV.delete("UMAXICA_RP_BROWSER_ADMISSION")
    assert_raises(KeyError) { RuntimeRole.serves?("base/app/roots", "rp-base-app-ww") }
  end

  test "the shared transitional role serves every controller, including unowned ones" do
    assert RuntimeRole.serves?("base/app/identity/birthdates", RuntimeRole::SHARED)
    assert RuntimeRole.serves?("unknown/app/roots", RuntimeRole::SHARED)
  end

  teardown { ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") }

  private

  def routed_controllers
    Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq
  end
end
