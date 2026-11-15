# frozen_string_literal: true

require "test_helper"

class CoreAppClientBridgeTest < ActiveSupport::TestCase
  test "public ID storage and validation retain the fixed NanoID contract" do
    assert_public_id_fixed_length(::CoreAppClientBridge)
  end

  test "legacy defaults resolve through the configured RP values" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    bridge = CoreAppClientBridge.create!(
      client:,
      rp_client_id: "core_app",
      host: "www-jp.umaxica.app",
    )

    assert_equal RpDeploymentBindingValue.client_id("core-app"), bridge.rp_client_id
    assert_equal "umaxica-core-app", bridge.audience
    assert_equal "jpx.umaxica.app", bridge.host
  end

  test "a non-Core RP identity is preserved" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    bridge = CoreAppClientBridge.create!(client:, rp_client_id: "external-client", audience: "external-audience")

    assert_equal "external-client", bridge.rp_client_id
    assert_equal "external-audience", bridge.audience
    assert_equal "jpx.umaxica.app", bridge.host
  end

  test "blank RP identity fields receive the configured defaults before validation" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    bridge = CoreAppClientBridge.create!(client:, rp_client_id: "", audience: "", host: "")

    assert_equal RpDeploymentBindingValue.client_id("core-app"), bridge.rp_client_id
    assert_equal "umaxica-core-app", bridge.audience
    assert_equal "jpx.umaxica.app", bridge.host
  end
end
