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

  test "Base App and Base Org expose their own RP sign-entry and callback routes" do
    {
      BASE_APP_HOST => "base/app",
      BASE_ORG_HOST => "base/org",
    }.each do |host, controller_prefix|
      sign_entry = Rails.application.routes.recognize_path("https://#{host}/sign", method: :get)
      sign_start = Rails.application.routes.recognize_path("https://#{host}/sign", method: :post)
      interruption = Rails.application.routes.recognize_path("https://#{host}/sign/interruption", method: :get)
      callback = Rails.application.routes.recognize_path("https://#{host}/oidc/callback", method: :get)

      assert_equal "#{controller_prefix}/sign/entries", sign_entry.fetch(:controller)
      assert_equal "show", sign_entry.fetch(:action)
      assert_equal "#{controller_prefix}/sign/entries", sign_start.fetch(:controller)
      assert_equal "create", sign_start.fetch(:action)
      assert_equal "#{controller_prefix}/sign/interruptions", interruption.fetch(:controller)
      assert_equal "show", interruption.fetch(:action)
      assert_equal "#{controller_prefix}/oidc/callbacks", callback.fetch(:controller)
      assert_equal "show", callback.fetch(:action)
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
