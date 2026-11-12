# frozen_string_literal: true

require "test_helper"

class AvatarPurgeDeferralUniquenessTest < ActiveSupport::TestCase
  test "deferral uniqueness belongs to the avatar and reason pair with PostgreSQL enforcement" do
    now = Time.utc(2026, 11, 12, 12)
    handle = Handle.create!(handle: "deferral-uniqueness", cooldown_until: now)
    avatar = Avatar.create!(active_handle: handle, capability_id: AvatarCapability::NORMAL)
    first = AvatarPurgeDeferral.record!(avatar: avatar, reason_code: "ownership_history", observed_at: now)
    duplicate = AvatarPurgeDeferral.new(
      avatar: avatar, reason_code: "ownership_history", attempt_count: 1, first_observed_at: now,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:reason_code, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarRecord.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    other_reason = AvatarPurgeDeferral.record!(
      avatar: avatar, reason_code: "retention_policy_pending", observed_at: now,
    )
    other_handle = Handle.create!(handle: "other-deferral-avatar", cooldown_until: now)
    other_avatar = Avatar.create!(active_handle: other_handle, capability_id: AvatarCapability::NORMAL)
    other_owner = AvatarPurgeDeferral.record!(avatar: other_avatar, reason_code: "ownership_history", observed_at: now)

    assert_not_equal first.id, other_reason.id
    assert_not_equal first.id, other_owner.id
    assert_equal 3, AvatarPurgeDeferral.where(avatar_id: [avatar.id, other_avatar.id]).count
    assert_predicate first.reload, :valid?
    first.reason_code = other_reason.reason_code

    assert_not first.valid?
    assert first.errors.of_kind?(:reason_code, :taken)
    first.reload.avatar = other_avatar

    assert_not first.valid?
    assert first.errors.of_kind?(:reason_code, :taken)
  end

  test "recording repeated deferrals preserves first observation and updates count without saving dirty avatar input" do
    now = Time.utc(2026, 11, 12, 12)
    handle = Handle.create!(handle: "deferral-observations", cooldown_until: now)
    avatar = Avatar.create!(active_handle: handle, capability_id: AvatarCapability::NORMAL)
    first = AvatarPurgeDeferral.record!(avatar: avatar, reason_code: "ownership_history", observed_at: now)
    avatar.public_id = "unsaved-change"
    repeated = AvatarPurgeDeferral.record!(avatar: avatar, reason_code: "ownership_history", observed_at: now + 1.hour)

    assert_equal first.id, repeated.id
    assert_equal 2, repeated.attempt_count
    assert_equal now, repeated.first_observed_at
    assert_equal now + 1.hour, repeated.last_observed_at
    assert_equal "unsaved-change", avatar.public_id
    assert_not_equal "unsaved-change", Avatar.find(avatar.id).public_id
  end
end
