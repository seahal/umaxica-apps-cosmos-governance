# frozen_string_literal: true

require "test_helper"

class CoreOrgOperatorBridgeTest < ActiveSupport::TestCase
  test "public ID storage and validation retain the fixed NanoID contract" do
    assert_public_id_fixed_length(::CoreOrgOperatorBridge)
  end

  test "legacy defaults resolve through the configured operator and expose the RP actor" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    bridge = CoreOrgOperatorBridge.create!(
      operator:,
      rp_client_id: "core_org",
      host: "www-jp.umaxica.org",
    )

    assert_equal RpDeploymentBindingValue.client_id("core-org"), bridge.rp_client_id
    assert_equal "umaxica-core-org", bridge.audience
    assert_equal "jpx.umaxica.org", bridge.host
    assert_equal operator, bridge.actor
    assert_equal operator.public_id, bridge.subject
    assert_predicate bridge, :core?
  end
end
