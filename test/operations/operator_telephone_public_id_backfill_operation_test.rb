# frozen_string_literal: true

require "test_helper"

class OperatorTelephonePublicIdBackfillOperationTest < ActiveSupport::TestCase
  test "rejects a scope unless it is an OperatorTelephone relation" do
    [nil, Operator.all].each do |scope|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(scope:, dry_run: true, batch_size: 1)
      end
    end
  end

  test "accepts the minimum and maximum supported batch sizes" do
    [1, 1000].each do |batch_size|
      result = OperatorTelephonePublicIdBackfillOperation.call(
        scope: OperatorTelephone.none, dry_run: true, batch_size:,
      )

      assert_equal({ assigned: 0, missing: 0 }, result)
      assert_predicate result, :frozen?
    end
  end

  test "rejects batch sizes immediately below and above the supported range" do
    [0, 1001].each do |batch_size|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.none, dry_run: true, batch_size:,
        )
      end
    end
  end

  test "rejects a dry-run mode that is not boolean" do
    [nil, "true"].each do |dry_run|
      assert_raises(ArgumentError) do
        OperatorTelephonePublicIdBackfillOperation.call(
          scope: OperatorTelephone.none, dry_run:, batch_size: 1,
        )
      end
    end
  end

  test "dry run reports the current identity state without changing a telephone" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = operator.staff_telephones.create!(
      raw_number: "+12025550999", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.reload.attributes

    result = OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.where(id: telephone.id), dry_run: true, batch_size: 1,
    )

    assert_equal({ assigned: 0, missing: 0 }, result)
    assert_equal original, telephone.reload.attributes
  end

  test "write mode leaves a current non-null immutable identity unchanged" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = operator.staff_telephones.create!(
      raw_number: "+12025550998", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.reload.attributes

    result = OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.where(id: telephone.id), dry_run: false, batch_size: 1000,
    )

    assert_equal({ assigned: 0, missing: 0 }, result)
    assert_equal original, telephone.reload.attributes
  end
end
