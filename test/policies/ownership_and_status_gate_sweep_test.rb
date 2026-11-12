# typed: false
# frozen_string_literal: true

require "test_helper"

# Ownership gates and status gates that decide whether one actor may act on
# another's record. Every arm that answers false is the one keeping a surface's
# accounts and organizations out of another surface's reach, and the checkpoint
# gate is what keeps a sign-in cycle from being advanced from the wrong step.
class OwnershipAndStatusGateSweepTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :operators, :operator_statuses

  test "a record type the account gate does not serve is never shown" do
    assert_not AccountPolicy.new(Object.new, user: clients(:one)).show?
  end

  test "a record type the organization gate does not serve is never shown" do
    assert_not OrganizationPolicy.new(Object.new, user: operators(:one)).show?
  end

  # Enforcement cases are staff-only across the board; a client holding one is
  # not a reason to read or raise them.
  test "enforcement cases are refused to anyone who is not an operator" do
    as_client = EnforcementCasePolicy.new(Object.new, user: clients(:one))

    assert_not as_client.index?
    assert_not as_client.show?
    assert_not as_client.create?

    # Being an operator is necessary but not sufficient: with no capability grant, every rule denies.
    as_operator = EnforcementCasePolicy.new(AppEnforcementCase.new, user: operators(:one))

    assert_not as_operator.index?
    assert_not as_operator.show?
    assert_not as_operator.create?
  end
end
