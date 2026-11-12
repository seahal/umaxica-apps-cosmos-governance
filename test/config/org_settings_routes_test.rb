# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgSettingsRoutesTest < ActiveSupport::TestCase
  test "Base ORG settings owns the management route and the old route is absent" do
    helper = Rails.application.routes.url_helpers
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    route = Rails.application.routes.recognize_path("https://#{base_host}/settings", method: :get)

    assert_equal "base/org/settings", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
    assert_equal "/settings", helper.base_org_settings_path
    assert_not_respond_to helper, :base_org_configuration_path
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{base_host}/configuration", method: :get)
    end
  end
end
