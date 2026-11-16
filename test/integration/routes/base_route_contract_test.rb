# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL")

  test "org support has no com enforcement routes" do
    removed_routes = [
      ["/support/com/enforcement_cases", :get],
      ["/support/com/enforcement_cases/new", :get],
      ["/support/com/enforcement_cases", :post],
      ["/support/com/enforcement_cases/1", :get],
      ["/support/com/enforcement_cases/1/approval/new", :get],
      ["/support/com/enforcement_cases/1/approval", :post],
      ["/support/com/enforcement_cases/1/release/new", :get],
      ["/support/com/enforcement_cases/1/release", :post],
      ["/support/com/enforcement_cases/1/appeal_review/new", :get],
      ["/support/com/enforcement_cases/1/appeal_review", :post],
    ]

    removed_routes.each do |path, method|
      assert_raises(ActionController::RoutingError, "#{method.upcase} #{path} must be unroutable") do
        Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}#{path}", method: method)
      end
    end
  end

  test "base network and developer hosts do not resolve Base routes" do
    %w(base.net.localhost base.dev.localhost).each do |host|
      %w(/revision /health).each do |path|
        assert_raises(ActionController::RoutingError, "#{host} must not serve #{path}") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end

  test "base app route contract" do
    [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, "www.umaxica.app",
     BASE_APP_HOST,].uniq.each do |host|
      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/",
        method: :get,
      )

      assert_equal "base/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health",
        method: :get,
      )

      assert_equal "base/app/healths", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/liveness",
        method: :get,
      )

      assert_equal "base/app/health/livenesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/readiness",
        method: :get,
      )

      assert_equal "base/app/health/readinesses", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/health/startup",
        method: :get,
      )

      assert_equal "base/app/health/startups", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/robots.txt",
        method: :get,
      )

      assert_equal "base/app/robots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/sitemap.xml",
        method: :get,
      )

      assert_equal "base/app/sitemaps", recognized[:controller]
      assert_equal "show", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/identity/emails",
        method: :get,
      )

      assert_equal "base/app/identity/emails", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/groups",
        method: :get,
      )

      assert_equal "base/app/groups", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/dashboard",
        method: :get,
      )

      assert_equal "base/app/roots", recognized[:controller]
      assert_equal "show", recognized[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{host}/oidc/authorization",
          method: :get,
        )
      end

      {
        ["/sign", :get] => ["base/app/sign/entries", "show"],
        ["/sign", :post] => ["base/app/sign/entries", "create"],
        ["/sign/interruption", :get] => ["base/app/sign/interruptions", "show"],
        ["/oidc/callback", :get] => ["base/app/oidc/callbacks", "show"],
        ["/oidc/closures", :post] => ["base/app/oidc/closures", "create"],
        ["/sign/out/new", :get] => ["base/app/sign_outs", "new"],
        ["/sign/out/edit", :get] => ["base/app/sign_outs", "edit"],
        ["/sign/out", :post] => ["base/app/sign_outs", "create"],
      }.each do |(path, method), (controller, action)|
        recognized = Rails.application.routes.recognize_path("https://#{host}#{path}", method:)

        assert_equal controller, recognized.fetch(:controller), "#{method.upcase} #{path}"
        assert_equal action, recognized.fetch(:action), "#{method.upcase} #{path}"
      end

      [
        ["/oauth/authorize", :get],
        ["/oauth/token", :post],
        ["/oauth/userinfo", :get],
        ["/oauth/revoke", :post],
        ["/oidc/logout", :get],
      ].each do |path, method|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
        end
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oidc", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{host}/lobby",
          method: :get,
        )
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/sign/out/complete", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{host}/sign/out",
          method: :delete,
        )
      end

      recognized = Rails.application.routes.recognize_path(
        "http://#{host}/csp-violation-report",
        method: :post,
      )

      assert_equal "base/app/csp_violation_reports", recognized[:controller]
      assert_equal "create", recognized[:action]
    end
  end
  test "base com route contract" do
    recognized = Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/", method: :get)

    assert_equal "base/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    {
      "/health" => "base/com/healths",
      "/health/liveness" => "base/com/health/livenesses",
      "/health/readiness" => "base/com/health/readinesses",
      "/health/startup" => "base/com/health/startups",
      "/robots.txt" => "base/com/robots",
      "/sitemap.xml" => "base/com/sitemaps",
    }.each do |path, controller|
      recognized = Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}#{path}", method: :get)

      assert_equal controller, recognized[:controller], path
    end

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "base com no longer routes credential, session, or identity resources" do
    %w(
      /dashboard /oidc/callback /sign/out/new /sign/out/edit /identity/standing
      /identity/sessions /preference/emails /.well-known/jwks.json
    ).each do |path|
      assert_raises(ActionController::RoutingError, "#{path} must stay unroutable on com") do
        Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}#{path}", method: :get)
      end
    end
  end
  test "base org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/",
      method: :get,
    )

    assert_equal "base/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "base/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "base/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "base/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "base/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "base/org/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "base/org/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/dashboard",
      method: :get,
    )

    assert_equal "base/org/roots", recognized[:controller]
    assert_equal "show", recognized[:action]

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
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_ORG_HOST}/lobby",
        method: :get,
      )
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

    recognized = Rails.application.routes.recognize_path(
      "http://#{BASE_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "base/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]
  end
end
