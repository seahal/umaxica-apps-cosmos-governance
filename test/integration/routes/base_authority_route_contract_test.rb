# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseAuthorityRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")

  test "route graph includes only Governance surfaces and retained operator tools" do
    retired_families = %w(auth visa core palm warp edit info news help docs guid)
    routed_families = Rails.application.routes.routes.filter_map do |route|
      route.defaults[:controller].to_s.split("/").first.presence
    end.uniq

    assert_empty routed_families & retired_families
  end

  test "base authority routes accept internal origin and cloudflared public hosts" do
    {
      "base.app.localhost" => "base/app/roots",
      "base.com.localhost" => "base/com/roots",
      "base.org.localhost" => "base/org/roots",
      "www.umaxica.app" => "base/app/roots",
      "www.umaxica.com" => "base/com/roots",
      "www.umaxica.org" => "base/org/roots",
    }.each do |host, controller|
      assert_recognizes(
        { controller: controller, action: "index" },
        { path: "http://#{host}/", method: :get },
      )
    end
  end

  test "base dashboard routes stay within the app and org faces" do
    # com is anonymous-only: it has no authenticated dashboard (two.md WU-3).
    {
      "www.umaxica.app" => "base/app/roots",
      "www.umaxica.org" => "base/org/roots",
    }.each do |host, controller|
      assert_recognizes(
        { controller: controller, action: "show" },
        { path: "http://#{host}/dashboard", method: :get },
      )
    end
  end

  test "base authority app static and health routes" do
    assert_recognizes(
      { controller: "base/app/roots", action: "index" },
      { path: "http://#{BASE_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/well_known/jwks", action: "show" },
      { path: "http://#{BASE_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/healths", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/livenesses", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/readinesses", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/startups", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/robots", action: "index" },
      { path: "http://#{BASE_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sitemaps", action: "show" },
      { path: "http://#{BASE_APP_HOST}/sitemap.xml", method: :get },
    )
  end

  test "base authority app operational routes exclude retired Auth endpoints" do
    assert_recognizes(
      { controller: "base/app/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/welcomes", action: "show" },
      { path: "http://#{BASE_APP_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/roots", action: "show" },
      { path: "http://#{BASE_APP_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/verification/cancellations", action: "create" },
      { path: "http://#{BASE_APP_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/selectors", action: "show" },
      { path: "http://#{BASE_APP_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/selectors", action: "update" },
      { path: "http://#{BASE_APP_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "base/app/switchers", action: "show" },
      { path: "http://#{BASE_APP_HOST}/switcher", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/switchers", action: "update" },
      { path: "http://#{BASE_APP_HOST}/switcher", method: :patch },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "base/app/oidc/callbacks", action: "show" },
      { path: "https://#{BASE_APP_HOST}/oidc/callback", method: :get },
    )
    assert_recognizes(
      { controller: "base/app/oidc/closures", action: "create" },
      { path: "https://#{BASE_APP_HOST}/oidc/closures", method: :post },
    )
    assert_recognizes(
      { controller: "base/app/sign_outs", action: "new" },
      { path: "https://#{BASE_APP_HOST}/sign/out/new", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/lobby", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/sign/out",
        method: :delete,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sso/logout", method: :post)
    end
  end

  test "base authority app account routes exclude Access protocol endpoints" do
    %w(/oauth/authorize /oauth/token /oauth/userinfo /oauth/revoke /oidc/logout
       /social/google/callback /social/apple/callback /social/failure).each do |path|
      assert_raises(ActionController::RoutingError, "#{path} belongs to Access") do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}#{path}", method: :get)
      end
    end

    assert_raises(ActionController::RoutingError, "social provider entry is owned by Access") do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/social/authentication/continuation",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/oauth/jwks", method: :get)
    end

    %w(/auth /auth/callback /auth/logout /oauth/callback /oauth/jwks /social/auth/google_app/continue
       /social/auth/google_app/completion).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}#{path}", method: :get)
      end
    end

    # Entity CRUD is plural; current-context display/switching lives at /switcher. The abandoned
    # /current/* namespace must not resolve on the app surface.
    [
      { path: "/current/organization", method: :get },
      { path: "/current/organization/edit", method: :get },
      { path: "/current/organization", method: :patch },
      { path: "/current/avatar", method: :get },
      { path: "/current/avatar/edit", method: :get },
      { path: "/current/avatar", method: :patch },
      { path: "/current/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end
  end

  test "base authority app singular current routes do not resolve" do
    # Singular current routes are intentionally absent; selection and switching stay on
    # /selector and /switcher, while CRUD remains pluralized.
    [
      { path: "/account", method: :get },
      { path: "/account/edit", method: :get },
      { path: "/account", method: :patch },
      { path: "/organization", method: :get },
      { path: "/organization/edit", method: :get },
      { path: "/organization", method: :patch },
      { path: "/avatar", method: :get },
      { path: "/avatar/edit", method: :get },
      { path: "/avatar", method: :patch },
      { path: "/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    [
      { path: "/avatars", method: :get },
      { path: "/avatars/example", method: :get },
      { path: "/avatars/example", method: :post },
      { path: "/avatars/example", method: :patch },
      { path: "/avatars/example", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    {
      index: { path: "/organizations" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/organizations", action: action.to_s },
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}", method: :get },
      )
    end

    assert_recognizes(
      { controller: "base/app/organizations", action: "show", id: "example" },
      { path: "http://#{BASE_APP_HOST}/organizations/example", method: :get, id: "example" },
    )

    {
      index: { method: :get, path: "/organizations/example/memberships" },
      new: { method: :get, path: "/organizations/example/memberships/new" },
      create: { method: :post, path: "/organizations/example/memberships" },
      edit: { method: :get, path: "/organizations/example/memberships/member-example/edit", id: "member-example" },
      update: { method: :patch, path: "/organizations/example/memberships/member-example", id: "member-example" },
      destroy: { method: :delete, path: "/organizations/example/memberships/member-example", id: "member-example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/organizations/memberships",
          action: action.to_s,
          organization_id: "example",
          id: opts[:id], }.compact,
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}",
          method: opts[:method],
          organization_id: "example",
          id: opts[:id], }.compact,
      )
    end

    {
      index: { path: "/accounts", method: :get },
      show: { path: "/accounts/example", method: :get, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/accounts", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/app/identities", action: "show" },
      { path: "http://#{BASE_APP_HOST}/identity", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preferences", action: "show" },
      { path: "http://#{BASE_APP_HOST}/preference", method: :get },
    )

    {
      region: %w(edit patch),
      timezone: %w(edit patch),
      language: %w(edit patch),
      currency: %w(edit patch),
      calendar: %w(edit patch),
      clock: %w(edit patch),
      motion: %w(edit patch),
      density: %w(edit patch),
      pagination: %w(edit patch),
      theme: %w(edit patch),
      cookie: %w(edit patch),
    }.each do |name, (edit_action, _update_verb)|
      assert_recognizes(
        { controller: "base/app/preference/#{name.to_s.pluralize}", action: edit_action },
        { path: "http://#{BASE_APP_HOST}/preference/#{name}/edit", method: :get },
      )

      assert_recognizes(
        { controller: "base/app/preference/#{name.to_s.pluralize}", action: "update" },
        { path: "http://#{BASE_APP_HOST}/preference/#{name}", method: :patch },
      )
    end

    assert_recognizes(
      { controller: "base/app/preference/customizations", action: "edit" },
      { path: "http://#{BASE_APP_HOST}/preference/customization/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preference/customizations", action: "destroy" },
      { path: "http://#{BASE_APP_HOST}/preference/customization", method: :delete },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "edit", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "destroy", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example", method: :delete },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "create", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example", method: :post },
    )

    %w(date time page_size).each do |name|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/preference/#{name}/edit", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/preference/#{name}", method: :patch)
      end
    end
  end

  test "base authority com route contract" do
    assert_recognizes(
      { controller: "base/com/roots", action: "index" },
      { path: "http://#{BASE_COM_HOST}/", method: :get },
    )

    {
      "/health" => ["base/com/healths", "show"],
      "/health/liveness" => ["base/com/health/livenesses", "show"],
      "/health/readiness" => ["base/com/health/readinesses", "show"],
      "/health/startup" => ["base/com/health/startups", "show"],
      "/revision" => ["base/com/revisions", "show"],
      "/robots.txt" => ["base/com/robots", "index"],
      "/sitemap.xml" => ["base/com/sitemaps", "show"],
      "/api/v0/health.json" => ["base/com/api/v0/healths", "show"],
      "/api/v0/revision.json" => ["base/com/api/v0/revisions", "show"],
    }.each do |path, (controller, action)|
      recognized = Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}#{path}", method: :get)

      assert_equal controller, recognized[:controller], path
      assert_equal action, recognized[:action], path
    end

    assert_recognizes(
      { controller: "base/com/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_COM_HOST}/csp-violation-report", method: :post },
    )

    # Anonymous visitors choose a region, language and presentation without signing in.
    assert_recognizes(
      { controller: "base/com/preferences", action: "show" },
      { path: "http://#{BASE_COM_HOST}/preference", method: :get },
    )

    {
      calendar: "base/com/preference/calendars",
      clock: "base/com/preference/clocks",
      cookie: "base/com/preference/cookies",
      currency: "base/com/preference/currencies",
      density: "base/com/preference/densities",
      language: "base/com/preference/languages",
      motion: "base/com/preference/motions",
      pagination: "base/com/preference/paginations",
      region: "base/com/preference/regions",
      screen: "base/com/preference/screens",
      theme: "base/com/preference/themes",
      timezone: "base/com/preference/timezones",
    }.each do |name, controller|
      assert_recognizes(
        { controller: controller, action: "edit" },
        { path: "http://#{BASE_COM_HOST}/preference/#{name}/edit", method: :get },
      )

      assert_recognizes(
        { controller: controller, action: "update" },
        { path: "http://#{BASE_COM_HOST}/preference/#{name}", method: :patch },
      )
    end

    assert_recognizes(
      { controller: "base/com/preference/customizations", action: "edit" },
      { path: "http://#{BASE_COM_HOST}/preference/customization/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/preference/customizations", action: "destroy" },
      { path: "http://#{BASE_COM_HOST}/preference/customization", method: :delete },
    )

    {
      "/api/v0/preferences/theme" => "base/com/api/v0/preferences/themes",
      "/api/v0/preferences/cookie" => "base/com/api/v0/preferences/cookies",
    }.each do |path, controller|
      assert_recognizes(
        { controller: controller, action: "show" },
        { path: "http://#{BASE_COM_HOST}#{path}", method: :get },
      )

      assert_recognizes(
        { controller: controller, action: "update" },
        { path: "http://#{BASE_COM_HOST}#{path}", method: :patch },
      )
    end
  end

  test "base authority com no longer routes credential, session, or identity resources" do
    # two.md WU-3 makes com anonymous-only. Verification, account, organization, and identity
    # routes stay on app and org; Auth/Visa sign-in and sign-out flows are retired.
    %w(
      /dashboard /welcome /oidc/callback /selector /switcher
      /sign/out/new /sign/out/edit /identity /identity/standing /identity/sessions
      /accounts /organizations /.well-known/jwks.json /preference/emails
    ).each do |path|
      assert_raises(ActionController::RoutingError, "#{path} must stay unroutable on com") do
        Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}#{path}", method: :get)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_COM_HOST}/verification/cancellation",
        method: :post,
      )
    end
  end
  test "base authority org route contract" do
    assert_recognizes(
      { controller: "base/org/roots", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/well_known/jwks", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/healths", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/livenesses", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/readinesses", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/startups", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/robots", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/sitemaps", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/welcomes", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/roots", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/verification/cancellations", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/selectors", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/selectors", action: "update" },
      { path: "http://#{BASE_ORG_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "base/org/switchers", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/switcher", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/switchers", action: "update" },
      { path: "http://#{BASE_ORG_HOST}/switcher", method: :patch },
    )

    {
      ["/sign", :get] => ["base/org/sign/entries", "show"],
      ["/sign", :post] => ["base/org/sign/entries", "create"],
      ["/sign/interruption", :get] => ["base/org/sign/interruptions", "show"],
      ["/oidc/callback", :get] => ["base/org/oidc/callbacks", "show"],
      ["/oidc/closures", :post] => ["base/org/oidc/closures", "create"],
      ["/sign/out", :get] => ["base/org/sign_outs", "show"],
      ["/sign/out/new", :get] => ["base/org/sign_outs", "new"],
      ["/sign/out/edit", :get] => ["base/org/sign_outs", "edit"],
      ["/sign/out", :post] => ["base/org/sign_outs", "create"],
      ["/sign/out/completion", :get] => ["base/org/sign_outs", "show"],
    }.each do |(path, method), (controller, action)|
      recognized = Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}#{path}", method:)

      assert_equal controller, recognized.fetch(:controller), "#{method.upcase} #{path}"
      assert_equal action, recognized.fetch(:action), "#{method.upcase} #{path}"
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc/authorization", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/lobby", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_ORG_HOST}/sign/out",
        method: :delete,
      )
    end
  end

  test "base authority org membership routes are read-only" do
    # Org memberships are read-only: changes are not routed until their authority is decided.
    assert_recognizes(
      { controller: "base/org/organizations/memberships",
        action: "show",
        organization_id: "example",
        id: "member-example", },
      { path: "http://#{BASE_ORG_HOST}/organizations/example/memberships/member-example",
        method: :get,
        organization_id: "example",
        id: "member-example", },
    )
    assert_raises(Minitest::Assertion) do
      assert_recognizes(
        { controller: "base/org/organizations/memberships",
          action: "destroy",
          organization_id: "example",
          id: "member-example", },
        { path: "http://#{BASE_ORG_HOST}/organizations/example/memberships/member-example", method: :delete },
      )
    end
  end

  test "base authority org route contract (continued)" do
    [
      { path: "/sso/authorize", method: :get },
      { path: "/sso/logout", method: :post },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_ORG_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization", method: :patch)
    end

    [
      { path: "/account", method: :get },
      { path: "/account/edit", method: :get },
      { path: "/account", method: :patch },
      { path: "/organization", method: :get },
      { path: "/organization/edit", method: :get },
      { path: "/organization", method: :patch },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_ORG_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :delete)
    end

    [
      ["/avatar", :get], ["/avatar/edit", :get], ["/avatar", :patch], ["/avatar", :delete],
    ].each do |path, method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}#{path}", method: method)
      end
    end

    {
      index: { path: "/organizations" },
      show: { path: "/organizations/example", id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/org/organizations", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_ORG_HOST}#{opts[:path]}", method: :get, id: opts[:id] }.compact,
      )
    end

    {
      index: { path: "/accounts", method: :get },
      show: { path: "/accounts/example", method: :get, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/org/accounts", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_ORG_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/org/settings", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/settings", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/iam", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/iam", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/system", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/system", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/audit", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/audit", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/support", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/support", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/billing", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/billing", method: :get },
    )

    # NOTE: /settings is omitted -- recognize_path does not enforce host constraints;
    # legacy/org/settings bleeds through. Integration tests cover the actual host boundary.
  end

  test "base authority settings routes are retired" do
    {
      BASE_APP_HOST => "app",
      BASE_COM_HOST => "com",
      BASE_ORG_HOST => "org",
    }.each_key do |host|
      [
        # NOTE: /settings (bare) is intentionally excluded -- recognize_path does not enforce host
        # constraints, so warp/*/settings routes bleed through. The actual host constraint is
        # verified by integration tests that make real HTTP requests.
        { path: "/settings/secrets", method: :get },
        { path: "/settings/secrets/enrollment", method: :post },
        { path: "/settings/secrets/secret-example/edit", method: :get },
        { path: "/settings/secrets/secret-example", method: :delete },
        { path: "/settings/secret_credentials", method: :get },
      ].each do |route|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{route.fetch(:path)}", method: route.fetch(:method))
        end
      end
    end
  end

  test "base app generic identity secret management routes are retired" do
    [
      ["/identity/secrets", :get],
      ["/identity/secrets/new", :get],
      ["/identity/secrets/example", :get],
      ["/identity/secrets/example/edit", :get],
      ["/identity/secrets", :post],
      ["/identity/secrets/example", :patch],
      ["/identity/secrets/example", :put],
      ["/identity/secrets/example", :delete],
      ["/identity/secrets/example/rotation", :post],
      ["/identity/secrets/example/removal", :post],
    ].each do |path, method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}#{path}", method: method)
      end
    end
  end

  test "base authority retired routes do not resolve" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/oauth/user_info",
        method: :get,
      )
    end

    # NOTE: /accounts resolves on all three Base authority surfaces as entity CRUD.

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/auth/acme/callback",
        method: :get,
      )
    end
  end

  test "retired Base authority and RP paths do not redirect on APP and ORG hosts" do
    [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_BASE_STAFF_URL")].each do |host|
      host! host
      https!
      %w(/oauth/user_info /auth/acme /auth/acme/callback /oidc/authorization /sign/callback).each do |path|
        get path

        assert_response :not_found, "#{host} #{path}"
        assert_nil response.location, "#{host} #{path}"
      end
    end
  end

  test "Base APP and ORG retain their own JWKS routes" do
    {
      "app" => ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      "org" => ENV.fetch("PUBLIC_BASE_STAFF_URL"),
    }.each do |surface, host|
      assert_recognizes(
        { controller: "base/#{surface}/well_known/jwks", action: "show" },
        { path: "http://#{host}/.well-known/jwks.json", method: :get },
      )
      if surface == "app"
        assert_recognizes(
          { controller: "base/app/oidc/callbacks", action: "show" },
          { path: "https://#{host}/oidc/callback", method: :get },
        )
      else
        assert_recognizes(
          { controller: "base/org/oidc/callbacks", action: "show" },
          { path: "https://#{host}/oidc/callback", method: :get },
        )
      end
      host! host
      https!
      get "/.well-known/jwks.json"

      assert_response :success
      assert_equal "application/json", response.media_type
    end
  end
end
