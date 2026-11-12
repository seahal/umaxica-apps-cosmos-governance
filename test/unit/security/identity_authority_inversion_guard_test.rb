# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Governance routes exclude Access, Sphere, Press, and Guid surfaces" do
    retired_families = %w(auth visa core palm warp edit info news help docs guid)
    routed_families = Rails.application.routes.routes.filter_map do |route|
      route.defaults[:controller].to_s.split("/").first.presence
    end.uniq

    assert_empty routed_families & retired_families
  end

  test "Base routes do not publish retired Access callbacks or OP endpoints" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [hosts.base_service.host, hosts.base_staff.host].each do |host|
      %w(/oauth/authorize /oauth/token /oauth/userinfo /oauth/revoke /oidc/logout
         /.well-known/openid-configuration /oidc/callback).each do |path|
        assert_raises(ActionController::RoutingError, "#{host} must not expose #{path}") do
          Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)
        end
      end
    end
  end

  test "Governance does not own the retired Access token refresh implementation" do
    assert_not Rails.root.join("app/operations/acme_refresh_token_issuer.rb").exist?
  end
end
