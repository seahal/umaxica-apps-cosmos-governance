# frozen_string_literal: true

require "test_helper"

class AccessOpModelBoundaryTest < ActiveSupport::TestCase
  test "both appeal realms refuse resolution before mutating the appeal or its audit" do
    app_appeal = AppEnforcementAppeal.new
    org_appeal = OrgEnforcementAppeal.new
    app_before = app_appeal.attributes
    org_before = org_appeal.attributes
    assert_raises(AccessOpDataUnavailableError) do
      app_appeal.resolve!(reviewer_operator_public_id: "", resolution_code: "approved")
    end
    assert_raises(AccessOpDataUnavailableError) do
      org_appeal.resolve!(
        reviewer_operator_public_id: "", resolution_code: "rejected",
        step_up_token: Object.new, step_up_actor: Object.new, step_up_evidence: Object.new,
      )
    end
    assert_equal app_before, app_appeal.attributes
    assert_equal org_before, org_appeal.attributes
    assert_not app_appeal.persisted?
    assert_not org_appeal.persisted?
  end
end
