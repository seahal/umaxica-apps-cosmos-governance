# frozen_string_literal: true

require "test_helper"

class RpDeploymentBindingValueTest < ActiveSupport::TestCase
  test "active Browser RP client ids contain only retained Base and Tech surfaces" do
    active = RpDeploymentBindingValue.active_client_ids

    assert_equal %w(base-app-ww base-org-ww tech-org-ww), active.sort
    assert_equal "base-app-ww", RpDeploymentBindingValue.client_id("base-app")
    assert_equal "base-org-ww", RpDeploymentBindingValue.client_id("base-org")
    assert_equal "tech-org-ww", RpDeploymentBindingValue.client_id("tech-org")
    assert_raises(RpDeploymentBindingValue::UnknownRp) do
      RpDeploymentBindingValue.client_id("unknown-app")
    end
  end
  test "retained Core bridge metadata does not activate a local RP" do
    region = RpDeploymentBindingValue.region

    assert_equal "core-app-#{region}", RpDeploymentBindingValue.client_id("core-app")
    assert_equal "core-org-#{region}", RpDeploymentBindingValue.client_id("core-org")
    assert_equal %w(base-app-ww base-org-ww tech-org-ww), RpDeploymentBindingValue.active_client_ids.sort
  end

  test "removed foreign RP families have no deployment binding" do
    %w(warp-app warp-org palm-app edit-org).each do |family|
      assert_raises(RpDeploymentBindingValue::UnknownRp) { RpDeploymentBindingValue.client_id(family) }
    end
  end
end
