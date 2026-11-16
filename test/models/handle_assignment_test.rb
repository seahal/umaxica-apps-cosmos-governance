# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_assignments
# Database name: avatar
#
#  id                          :bigint           not null, primary key
#  valid_from                  :datetime         not null
#  valid_to                    :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  assigned_by_actor_id        :bigint
#  avatar_id                   :bigint           not null
#  handle_assignment_status_id :bigint
#  handle_id                   :bigint           not null
#
# Indexes
#
#  index_handle_assignments_on_assigned_by_actor_id         (assigned_by_actor_id)
#  index_handle_assignments_on_avatar_id                    (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_avatar_id_and_valid_from     (avatar_id,valid_from DESC)
#  index_handle_assignments_on_handle_assignment_status_id  (handle_assignment_status_id)
#  index_handle_assignments_on_handle_id                    (handle_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_handle_id_and_valid_from     (handle_id,valid_from DESC)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (handle_assignment_status_id => handle_assignment_statuses.id)
#  fk_rails_...  (handle_id => handles.id)
#

require "test_helper"
require_relative "../support/avatar_test_factory"

class HandleAssignmentTest < ActiveSupport::TestCase
  setup do
    unique_suffix = SecureRandom.hex(4)
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    @system_handle = Handle.create!(
      handle: "__unassigned__#{unique_suffix}",
      is_system: true,
      cooldown_until: 1.week.from_now,
    )
    @avatar = AvatarTestFactory.create!(
      moniker: "Avatar",
      capability: @capability,
      active_handle: @system_handle,
    )
  end

  test "current_attributes returns handle and avatar ids" do
    assert_equal [:handle_id, :avatar_id], HandleAssignment.current_attributes
  end

  test "valid_to defaults to infinity" do
    assignment = HandleAssignment.create!(
      avatar: @avatar,
      handle: @system_handle,
      valid_from: Time.current,
    )

    valid_to = assignment.reload.valid_to

    assert_predicate valid_to, :present?
    assert valid_to.to_s == "infinity" || (valid_to.is_a?(Float) && valid_to == Float::INFINITY)
  end

  test "prevents multiple active assignments for the same handle" do
    HandleAssignment.create!(
      avatar: @avatar,
      handle: @system_handle,
      valid_from: Time.current,
    )

    other_handle = Handle.create!(handle: "other-#{SecureRandom.hex(4)}", cooldown_until: 1.week.from_now)
    other_avatar = AvatarTestFactory.create!(
      moniker: "Another",
      capability: @capability,
      active_handle: other_handle,
    )

    assert_raises ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do
      HandleAssignment.create!(
        avatar: other_avatar,
        handle: @system_handle,
        valid_from: Time.current,
      )
    end
  end

  test "finite history remains writable beside a current assignment and cannot become a second current row" do
    now = Time.utc(2026, 11, 12, 12)
    current = HandleAssignment.create!(avatar: @avatar, handle: @system_handle, valid_from: now)
    historical = HandleAssignment.new(
      avatar: @avatar, handle: @system_handle, valid_from: now - 2.days, valid_to: now - 1.day,
    )

    assert_predicate historical, :valid?
    historical.save!
    historical.update!(valid_from: now - 3.days)

    assert_equal now - 3.days, historical.reload.valid_from
    assert_equal [current.id], HandleAssignment.current.where(avatar: @avatar).pluck(:id)

    historical.valid_to = Float::INFINITY

    assert_not historical.valid?
    assert historical.errors.of_kind?(:handle_id, :taken)
    assert historical.errors.of_kind?(:avatar_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { historical.save! }
    assert_equal now - 1.day, historical.reload.valid_to
  end

  test "current duplicate is rejected before save and by PostgreSQL when validation is bypassed" do
    now = Time.utc(2026, 11, 12, 12)
    HandleAssignment.create!(avatar: @avatar, handle: @system_handle, valid_from: now)
    duplicate = HandleAssignment.new(avatar: @avatar, handle: @system_handle, valid_from: now)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:handle_id, :taken)
    assert duplicate.errors.of_kind?(:avatar_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      HandleAssignment.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    assert_equal 1, HandleAssignment.current.where(avatar: @avatar).count
  end
end
