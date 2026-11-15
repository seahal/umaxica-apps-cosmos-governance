# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceAdultContentGateTest < ActiveSupport::TestCase
  test "app preference gate distinguishes approved, denied, and unset choices" do
    approved = AppPreferenceAdultContentGate.new(option_id: AppPreferenceAdultContentGateOption::APPROVED)
    denied = AppPreferenceAdultContentGate.new(option_id: AppPreferenceAdultContentGateOption::DENY)
    unset = AppPreferenceAdultContentGate.new(option_id: AppPreferenceAdultContentGateOption::NOTHING)

    assert_predicate approved, :approved?
    assert_not approved.denied?
    assert_not approved.enabled?
    assert_not denied.approved?
    assert_predicate denied, :denied?
    assert_predicate denied, :enabled?
    assert_not unset.approved?
    assert_not unset.denied?
    assert_not unset.enabled?
  end

  test "client preference gate distinguishes approved, denied, and unset choices" do
    approved = ClientPreferenceAdultContentGate.new(option_id: ClientPreferenceAdultContentGateOption::APPROVED)
    denied = ClientPreferenceAdultContentGate.new(option_id: ClientPreferenceAdultContentGateOption::DENY)
    unset = ClientPreferenceAdultContentGate.new(option_id: ClientPreferenceAdultContentGateOption::NOTHING)

    assert_predicate approved, :approved?
    assert_not approved.denied?
    assert_not approved.enabled?
    assert_not denied.approved?
    assert_predicate denied, :denied?
    assert_predicate denied, :enabled?
    assert_not unset.approved?
    assert_not unset.denied?
    assert_not unset.enabled?
  end

  test "com preference gate distinguishes approved, denied, and unset choices" do
    approved = ComPreferenceAdultContentGate.new(option_id: ComPreferenceAdultContentGateOption::APPROVED)
    denied = ComPreferenceAdultContentGate.new(option_id: ComPreferenceAdultContentGateOption::DENY)
    unset = ComPreferenceAdultContentGate.new(option_id: ComPreferenceAdultContentGateOption::NOTHING)

    assert_predicate approved, :approved?
    assert_not approved.denied?
    assert_not approved.enabled?
    assert_not denied.approved?
    assert_predicate denied, :denied?
    assert_predicate denied, :enabled?
    assert_not unset.approved?
    assert_not unset.denied?
    assert_not unset.enabled?
  end

  test "operator preference gate distinguishes approved, denied, and unset choices" do
    approved = OperatorPreferenceAdultContentGate.new(option_id: OperatorPreferenceAdultContentGateOption::APPROVED)
    denied = OperatorPreferenceAdultContentGate.new(option_id: OperatorPreferenceAdultContentGateOption::DENY)
    unset = OperatorPreferenceAdultContentGate.new(option_id: OperatorPreferenceAdultContentGateOption::NOTHING)

    assert_predicate approved, :approved?
    assert_not approved.denied?
    assert_not approved.enabled?
    assert_not denied.approved?
    assert_predicate denied, :denied?
    assert_predicate denied, :enabled?
    assert_not unset.approved?
    assert_not unset.denied?
    assert_not unset.enabled?
  end

  test "org preference gate distinguishes approved, denied, and unset choices" do
    approved = OrgPreferenceAdultContentGate.new(option_id: OrgPreferenceAdultContentGateOption::APPROVED)
    denied = OrgPreferenceAdultContentGate.new(option_id: OrgPreferenceAdultContentGateOption::DENY)
    unset = OrgPreferenceAdultContentGate.new(option_id: OrgPreferenceAdultContentGateOption::NOTHING)

    assert_predicate approved, :approved?
    assert_not approved.denied?
    assert_not approved.enabled?
    assert_not denied.approved?
    assert_predicate denied, :denied?
    assert_predicate denied, :enabled?
    assert_not unset.approved?
    assert_not unset.denied?
    assert_not unset.enabled?
  end

  test "app option catalog restores its fixed choices" do
    AppPreferenceAdultContentGateOption.ensure_defaults!

    assert_equal AppPreferenceAdultContentGateOption::DEFAULTS,
                 AppPreferenceAdultContentGateOption.order(:id).pluck(:id)
  end

  test "client option catalog restores its fixed choices" do
    ClientPreferenceAdultContentGateOption.ensure_defaults!

    assert_equal ClientPreferenceAdultContentGateOption::DEFAULTS,
                 ClientPreferenceAdultContentGateOption.order(:id).pluck(:id)
  end

  test "operator option catalog restores its fixed choices" do
    OperatorPreferenceAdultContentGateOption.ensure_defaults!

    assert_equal OperatorPreferenceAdultContentGateOption::DEFAULTS,
                 OperatorPreferenceAdultContentGateOption.order(:id).pluck(:id)
  end

  test "org option catalog restores its fixed choices" do
    OrgPreferenceAdultContentGateOption.ensure_defaults!

    assert_equal OrgPreferenceAdultContentGateOption::DEFAULTS,
                 OrgPreferenceAdultContentGateOption.order(:id).pluck(:id)
  end
end
