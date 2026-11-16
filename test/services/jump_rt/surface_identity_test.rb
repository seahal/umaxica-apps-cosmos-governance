# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtSurfaceIdentityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Jump issuer capability includes the owned Base browser surfaces" do
    expected = {
      "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
      "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
    }

    assert_equal 2, JumpRtSurface::ISSUER_NAMESPACES.size
    assert_equal expected, JumpRtSurface::ISSUER_ORIGIN_ENV
    assert_equal expected.keys.sort, JumpRtSurface::ISSUER_NAMESPACES.sort
  end

  test "unknown namespaces have no Jump issuer capability" do
    assert_raises(JumpRtConfigurationError, "UNOWNED_SURFACE") do
      JumpRtSurface.normalize_namespace("UNOWNED_SURFACE")
    end
    [nil, "", "0", "invalid\u0000"].each do |namespace|
      assert_raises(JumpRtConfigurationError, namespace.inspect) { JumpRtSurface.normalize_namespace(namespace) }
    end
  end

  test "only Base browser controllers issue Jump RTs in this app" do
    assert_equal "BASE_APP", JumpRtSurface.namespace_for_controller("Base::App::RootsController")
    assert_equal "BASE_ORG", JumpRtSurface.namespace_for_controller("Base::Org::RootsController")

    %w(Tech::Org Unowned::Surface).each do |namespace|
      assert_raises(JumpRtConfigurationError, namespace) do
        JumpRtSurface.namespace_for_controller("#{namespace}::RootsController")
      end
    end
  end

  test "issuer, return origin, and issuer JWKS URI derive from the PUBLIC_* surface origin" do
    env = { "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app" }

    assert_equal "https://www.umaxica.app", JumpRtSurface.issuer_origin("BASE_APP", env: env)
    assert_equal "https://www.umaxica.app/.well-known/jwks.json", JumpRtSurface.issuer_jwks_uri("BASE_APP", env: env)
  end

  test "an explicit https scheme on the PUBLIC_* origin is accepted" do
    env = { "PUBLIC_BASE_SERVICE_URL" => "https://www.umaxica.app" }

    assert_equal "https://www.umaxica.app", JumpRtSurface.issuer_origin("BASE_APP", env: env)
  end

  test "missing Base surface origin fails closed and names the setting" do
    error = assert_raises(JumpRtConfigurationError) { JumpRtSurface.issuer_origin("BASE_ORG", env: {}) }

    assert_match(/PUBLIC_BASE_STAFF_URL/, error.message)
  end

  {
    "blank" => "",
    "zero sentinel" => "0",
    "NUL character" => "www.umaxica.app\u0000",
    "control character" => "www.umaxica.app\n",
    "http scheme" => "http://www.umaxica.app",
    "malformed" => "https://www umaxica app",
    "localhost" => "localhost",
    "localhost subdomain" => "base.app.localhost",
    "local suffix" => "base.local",
    "internal suffix" => "base.internal",
    "private IPv4 literal" => "192.168.1.1",
    "loopback IPv4 literal" => "127.0.0.1",
    "link-local IPv4 literal" => "169.254.1.1",
    "loopback IPv6 literal" => "https://[::1]",
    "userinfo" => "https://user@www.umaxica.app",
    "path" => "https://www.umaxica.app/base",
    "query" => "https://www.umaxica.app?x=1",
    "fragment" => "https://www.umaxica.app#x",
    "port" => "https://www.umaxica.app:3000",
  }.each do |label, raw|
    test "PUBLIC_* Jump issuer origin rejects #{label}" do
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.issuer_origin("BASE_APP", env: { "PUBLIC_BASE_SERVICE_URL" => raw })
      end
    end
  end

  # Rails.env never selects a Jump identity: the issuer is the PUBLIC_* origin whose JWKS publishes
  # the active signing key, whichever environment holds that key
  # (adr/jump-directed-rails-handoff-contract.md).
  test "development Rails may present a canonical public issuer origin" do
    canonical = { "BASE_APP" => "www.umaxica.app" }

    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      canonical.each do |namespace, host|
        env = { JumpRtSurface::ISSUER_ORIGIN_ENV.fetch(namespace) => host }

        assert_equal "https://#{host}", JumpRtSurface.issuer_origin(namespace, env: env), namespace
      end
    end
  end

  test "issuer origin validation is identical in every Rails environment" do
    %w(development test production).each do |name|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(name)) do
        assert_equal "https://www.umaxica.app",
                     JumpRtSurface.issuer_origin("BASE_APP", env: { "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app" }),
                     name
        assert_raises(JumpRtConfigurationError, name) do
          JumpRtSurface.issuer_origin("BASE_APP", env: { "PUBLIC_BASE_SERVICE_URL" => "base.app.localhost" })
        end
      end
    end
  end
end
