# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

module Retention
  class CrossDatabaseChildPurgeTest < ActiveSupport::TestCase
    test "unavailable child-purge authority preserves both source children and chronicle audit" do
      user = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate,
        status_id: ClientStatus::ACTIVE,
      )

      notification = ClientNotificationRecord.create!(client: user)

      capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      handle = Handle.create!(handle: "cdp_h-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
      avatar = AvatarTestFactory.create!(moniker: "Cdp", capability: capability, active_handle: handle)
      assignment = avatar.avatar_assignments.create!(user: user, role: "owner")

      chronicle = ClientChronicle.create!(
        user: user,
        user_chronicle_level: ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::INFO),
        user_chronicle_event: ClientChronicleEvent.find(ClientChronicleEvent::LOGIN_SUCCESS),
        timestamp: Time.current,
        ip_address: "192.168.1.1",
      )

      assert_raises(AccessOpDataUnavailableError) { RetentionCrossDatabaseChildPurge.call(actor: user) }

      assert ClientNotificationRecord.exists?(notification.id),
             "notification records must remain until purge authority is available"
      assert AvatarAssignment.exists?(assignment.id),
             "Avatar assignments must remain until purge authority is available"
      assert ClientChronicle.exists?(chronicle.id),
             "chronicle (audit) must be retained across actor purge"
    end

    test "unavailable purge refuses before accessing a failing child database and retries remain safe" do
      user = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate,
        status_id: ClientStatus::ACTIVE,
      )
      notification = ClientNotificationRecord.create!(client: user)

      capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      handle = Handle.create!(handle: "CdpPartial-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
      avatar = AvatarTestFactory.create!(moniker: "CdpPartial", capability: capability, active_handle: handle)
      assignment = avatar.avatar_assignments.create!(user: user, role: "owner")

      AvatarAssignment.stub(
        :where,
        ->(*) { raise ActiveRecord::StatementInvalid, "synthetic child database failure" },
      ) do
        assert_raises(AccessOpDataUnavailableError) { RetentionCrossDatabaseChildPurge.call(actor: user) }
      end

      assert ClientNotificationRecord.exists?(notification.id)
      assert AvatarAssignment.exists?(assignment.id)

      assert_raises(AccessOpDataUnavailableError) { RetentionCrossDatabaseChildPurge.call(actor: user) }

      assert ClientNotificationRecord.exists?(notification.id)
      assert AvatarAssignment.exists?(assignment.id)
      assert_raises(AccessOpDataUnavailableError) { RetentionCrossDatabaseChildPurge.call(actor: user) }
    end

    test "rejects unsupported actor types explicitly" do
      assert_raises(ArgumentError) do
        RetentionCrossDatabaseChildPurge.call(actor: Object.new)
      end
    end
  end
end
