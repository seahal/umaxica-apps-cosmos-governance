# typed: false
# frozen_string_literal: true

require "test_helper"

class AccountStandingResolverTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "returns good standing when neither realm has an active case for the principal" do
    app_standing = AccountStandingResolver.call(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: "no-app-standing-case",
    )
    org_standing = AccountStandingResolver.call(
      enforcement_case_class: OrgEnforcementCase,
      principal_public_id: "no-org-standing-case",
    )

    assert_equal :good, app_standing.level
    assert_empty app_standing.decisions
    assert_equal :good, org_standing.level
    assert_empty org_standing.decisions
  end
end
