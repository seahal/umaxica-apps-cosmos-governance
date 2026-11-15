# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeQuotaPolicyPublicMethodsTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "active client and operator owners have remaining account and organization capacity" do
    client = clients(:one)
    client.update!(status_id: ClientStatus::ACTIVE)
    operator = operators(:one)
    operator.update!(status_id: OperatorStatus::ACTIVE)

    client_account_quota = Acme::AccountQuotaPolicy.new(surface: :app, principal: client)
    client_organization_quota = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client)
    operator_account_quota = Acme::AccountQuotaPolicy.new(surface: :org, principal: operator)
    operator_organization_quota = Acme::OrganizationQuotaPolicy.new(surface: :org, principal: operator)

    assert_equal Acme::QuotaLimits::ACCOUNT_LIMIT, client_account_quota.remaining
    assert_not_predicate client_account_quota, :exceeded?
    assert_equal Acme::QuotaLimits::ORGANIZATION_LIMIT, client_organization_quota.remaining
    assert_not_predicate client_organization_quota, :exceeded?
    assert_equal Acme::QuotaLimits::ACCOUNT_LIMIT, operator_account_quota.remaining
    assert_not_predicate operator_account_quota, :exceeded?
    assert_equal Acme::QuotaLimits::ORGANIZATION_LIMIT, operator_organization_quota.remaining
    assert_not_predicate operator_organization_quota, :exceeded?
  end

  test "inactive client and operator owners have no remaining capacity and are exceeded" do
    client_account_quota = Acme::AccountQuotaPolicy.new(surface: :app, principal: clients(:one))
    client_organization_quota = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: clients(:one))
    operator_account_quota = Acme::AccountQuotaPolicy.new(surface: :org, principal: operators(:one))
    operator_organization_quota = Acme::OrganizationQuotaPolicy.new(surface: :org, principal: operators(:one))

    assert_equal 0, client_account_quota.remaining
    assert_predicate client_account_quota, :exceeded?
    assert_equal 0, client_organization_quota.remaining
    assert_predicate client_organization_quota, :exceeded?
    assert_equal 0, operator_account_quota.remaining
    assert_predicate operator_account_quota, :exceeded?
    assert_equal 0, operator_organization_quota.remaining
    assert_predicate operator_organization_quota, :exceeded?
  end
end
