# typed: false
# frozen_string_literal: true

require "test_helper"

class AccountStandingRouteContractTest < ActionDispatch::IntegrationTest
  test "app account standing uses the app identity boundary" do
    route = Rails.application.routes.recognize_path("http://base.app.localhost/identity/standing?ri=jp", method: :get)

    assert_equal({ controller: "base/app/identity/standings", action: "show" }, route)
  end

  test "org account standing uses the org identity boundary" do
    route = Rails.application.routes.recognize_path("http://base.org.localhost/identity/standing?ri=jp", method: :get)

    assert_equal({ controller: "base/org/identity/standings", action: "show" }, route)
  end

  test "the retired Access recovery flow is absent from the Base RP" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/identity/recovery/session/new?ri=jp", method: :get)
    end
  end
end
