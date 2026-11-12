# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseRpEntrypointsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  BASE_APP_HOST = HOSTS.base_service.host
  BASE_ORG_HOST = HOSTS.base_staff.host

  test "Base does not expose a local Access authorization launcher" do
    [BASE_APP_HOST, BASE_ORG_HOST].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oidc/authorization", method: :get)
      end
    end
  end

  test "Base app and org do not expose Auth-dependent sign-in callbacks" do
    [BASE_APP_HOST, BASE_ORG_HOST].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{host}/oidc/callback", method: :get)
      end
    end
  end

  test "Base roots render their control-plane homes" do
    host! BASE_APP_HOST
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component

    host! BASE_ORG_HOST
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end
end
