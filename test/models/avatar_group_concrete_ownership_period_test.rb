# frozen_string_literal: true

require "test_helper"

class AvatarGroupConcreteOwnershipPeriodTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "direct SQL cannot change or delete concrete Group ownership history" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "concrete-group-account-#{SecureRandom.hex(4)}",
      name: "Concrete Group",
      state: "active",
    )
    period = AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "concrete-group-owner",
      valid_from: group.created_at,
    )

    change_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AvatarRecord.transaction(requires_new: true) do
          AvatarRecord.connection.execute(
            "UPDATE avatar_group_concrete_ownership_periods " \
            "SET owner_collective_public_id = 'changed-group-owner' WHERE id = #{period.id}",
          )
        end
      end
    delete_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AvatarRecord.transaction(requires_new: true) do
          AvatarRecord.connection.execute(
            "DELETE FROM avatar_group_concrete_ownership_periods WHERE id = #{period.id}",
          )
        end
      end

    assert_match(/immutable|history/i, change_error.message)
    assert_match(/immutable|history/i, delete_error.message)
    assert AvatarGroupConcreteOwnershipPeriod.exists?(period.id)
  end

  test "direct SQL cannot truncate concrete Group ownership history" do
    group = AvatarGroup.create!(
      account_surface: "org",
      account_public_id: "truncate-group-account-#{SecureRandom.hex(4)}",
      name: "Truncate Group",
      state: "active",
    )
    AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "truncate-group-owner",
      valid_from: group.created_at,
    )

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AvatarRecord.transaction(requires_new: true) do
          AvatarRecord.connection.execute("TRUNCATE avatar_group_concrete_ownership_periods")
        end
      end

    assert_match(/truncate|history/i, error.message)
  end

  test "current? distinguishes the open period from a closed historical period" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "period-state-account-#{SecureRandom.hex(4)}",
      name: "Period state",
      state: "active",
    )
    transfer_at = Time.utc(2026, 11, 13)
    historical = AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "period-state-owner",
      valid_from: transfer_at - 1.hour,
      valid_to: transfer_at,
    )
    current = AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "period-state-successor",
      valid_from: transfer_at,
    )

    assert_not_predicate historical, :current?
    assert_predicate current, :current?
  end
end
