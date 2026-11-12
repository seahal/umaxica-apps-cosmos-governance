# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySettingsMigrationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  IDENTITY_LISTS = {
    "/identity/passkeys" => ["base/app/identity/passkeys", "index"],
    "/identity/totps" => ["base/app/identity/totps", "index"],
    "/identity/emails" => ["base/app/identity/emails", "index"],
    "/identity/telephones" => ["base/app/identity/telephones", "index"],
  }.freeze

  test "Base keeps the read-only identity screens" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host

    IDENTITY_LISTS.each do |path, (controller, action)|
      route = Rails.application.routes.recognize_path("https://#{host}#{path}?ri=jp", method: :get)

      assert_equal controller, route.fetch(:controller), path
      assert_equal action, route.fetch(:action), path
    end
  end

  test "Base does not register local credential or session mutations" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    routes = [
      ["/identity/passkeys", :post],
      ["/identity/passkeys/1", :patch],
      ["/identity/passkeys/1", :delete],
      ["/identity/totps", :post],
      ["/identity/totps/1", :patch],
      ["/identity/totps/1", :delete],
      ["/identity/emails", :post],
      ["/identity/emails/1", :delete],
      ["/identity/emails/registration", :get],
      ["/identity/emails/registration", :post],
      ["/identity/emails/registration", :patch],
      ["/identity/telephones", :post],
      ["/identity/telephones/1", :delete],
      ["/identity/telephones/registration", :get],
      ["/identity/telephones/registration", :post],
      ["/identity/telephones/registration", :patch],
      ["/identity/sessions/1", :delete],
    ]

    routes.each do |path, method|
      assert_raises(ActionController::RoutingError, "#{method.upcase} #{path}") do
        Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
      end
    end
  end
end
