# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseGatewayRootsTest < ActionDispatch::IntegrationTest
  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)

  test "Base app, com, and org roots render the control-plane home" do
    [
      [HOSTS.base_service.host, :base_app_root_path, "base/app/roots/index"],
      [HOSTS.base_corporate.host, :base_com_root_path, "base/com/roots/index"],
      [HOSTS.base_staff.host, :base_org_root_path, "base/org/roots/index"],
    ].each do |host, helper, component|
      host! host
      get public_send(helper, ri: "jp", host: host)

      assert_response :success
      assert_equal component, inertia_component
    end
  end
end
