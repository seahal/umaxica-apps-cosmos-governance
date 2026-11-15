# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientPolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "a Client can read and update its own record" do
    client = clients(:one)
    policy = ClientPolicy.new(client, user: client)

    assert policy.apply(:show?)
    assert policy.apply(:update?)
    assert policy.apply(:edit?)
  end

  test "a Client cannot read or update another Client record" do
    policy = ClientPolicy.new(clients(:two), user: clients(:one))

    assert_not policy.apply(:show?)
    assert_not policy.apply(:update?)
  end

  test "registration, listing, and deletion are denied by the self-service policy" do
    client = clients(:one)
    policy = ClientPolicy.new(client, user: client)

    assert_not policy.apply(:index?)
    assert_not policy.apply(:create?)
    assert_not policy.apply(:new?)
    assert_not policy.apply(:destroy?)
  end

  test "an Operator is denied by the Client policy and receives no Client scope" do
    policy = ClientPolicy.new(clients(:one), user: operators(:one))

    %i(index? show? create? update? destroy?).each do |rule|
      assert_not policy.apply(rule), "ClientPolicy must deny Operators for #{rule}"
    end
    assert_empty policy.apply_scope(Client.all, type: :active_record_relation)
  end

  test "Client scope contains only that Client and unauthenticated scope is empty" do
    client = clients(:one)

    assert_equal [client.id], ClientPolicy.new(Client, user: client)
      .apply_scope(Client.all, type: :active_record_relation).pluck(:id)
    assert_empty ClientPolicy.new(Client, user: nil)
      .apply_scope(Client.all, type: :active_record_relation)
  end
end
