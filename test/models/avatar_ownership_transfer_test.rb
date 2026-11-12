# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarOwnershipTransferTest < ActiveSupport::TestCase
  test "database rejects blank identifiers even when model validations are bypassed" do
    HandleStatus.ensure_defaults!
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)

    {
      public_id: "public_id",
      from_owner_collective_public_id: "source owner id",
      to_owner_collective_public_id: "target owner id",
      request_actor_public_id: "request actor id",
    }.each do |column, label|
      handle = Handle.create!(
        handle: "transfer-check-#{SecureRandom.hex(5)}",
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
      avatar = AvatarTestFactory.create!(
        moniker: "Transfer #{SecureRandom.hex(2)}",
        capability: capability,
        active_handle: handle,
      )
      requested_at = Time.current
      attributes = {
        avatar_id: avatar.id,
        public_id: SecureRandom.hex(12),
        from_owner_surface: "app",
        from_owner_collective_public_id: "source-owner",
        to_owner_surface: "org",
        to_owner_collective_public_id: "target-owner",
        state: "pending",
        requested_at: requested_at,
        expires_at: requested_at + 5.days,
        request_actor_surface: "app",
        request_actor_public_id: "source-actor",
        created_at: requested_at,
        updated_at: requested_at,
      }
      attributes[column] = " \t"

      assert_raises(ActiveRecord::StatementInvalid, "blank #{label}") do
        AvatarRecord.transaction(requires_new: true) do
          AvatarOwnershipTransfer.insert_all!([attributes])
        end
      end
    end
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::AvatarOwnershipTransfer)
  end

  test "only pending candidates participate in the single pending transfer constraint" do
    now = Time.utc(2026, 11, 12, 12)
    handle = Handle.create!(handle: "pending-transfer-contract", cooldown_until: now)
    avatar = Avatar.create!(active_handle: handle, capability_id: AvatarCapability::NORMAL)
    attributes = {
      avatar: avatar,
      from_owner_surface: "app",
      from_owner_collective_public_id: "source",
      to_owner_surface: "org",
      to_owner_collective_public_id: "destination",
      request_actor_surface: "app",
      request_actor_public_id: "requester",
      requested_at: now,
      expires_at: now + 5.days,
      state: "pending",
    }
    pending = AvatarOwnershipTransfer.create!(attributes)
    duplicate = AvatarOwnershipTransfer.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:avatar_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarRecord.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end

    {
      "accepted" => { accepted_at: now, accept_actor_surface: "org", accept_actor_public_id: "acceptor" },
      "cancelled" => { cancelled_at: now, cancel_actor_surface: "app", cancel_actor_public_id: "canceller" },
      "expired" => { expired_at: now },
    }.each do |state, facts|
      historical = AvatarOwnershipTransfer.create!(attributes.merge(state: state, **facts))

      assert_equal state, historical.reload.state
      assert_equal [pending.id], AvatarOwnershipTransfer.pending.where(avatar: avatar).pluck(:id)
      historical.assign_attributes(
        state: "pending", accepted_at: nil, accept_actor_surface: nil, accept_actor_public_id: nil,
        cancelled_at: nil, cancel_actor_surface: nil, cancel_actor_public_id: nil, expired_at: nil,
      )

      assert_not historical.valid?
      assert historical.errors.of_kind?(:avatar_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { historical.save! }
      assert_equal state, historical.reload.state
    end
  end
end
