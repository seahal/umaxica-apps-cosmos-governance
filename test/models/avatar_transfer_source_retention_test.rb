# frozen_string_literal: true

require "test_helper"

class AvatarTransferSourceRetentionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    [AvatarEnterpriseOwnershipPeriod, AvatarEnterpriseToEnterpriseTransferDetail, "enterprise_to_enterprise",
     { enterprise_public_id: "source-enterprise" },
     { source_enterprise_public_id: "source-enterprise", destination_enterprise_public_id: "target-enterprise" },],
    [AvatarEnterpriseOwnershipPeriod, AvatarEnterpriseToBureauTransferDetail, "enterprise_to_bureau",
     { enterprise_public_id: "source-enterprise" },
     { source_enterprise_public_id: "source-enterprise", destination_bureau_public_id: "target-bureau" },],
    [AvatarBureauOwnershipPeriod, AvatarBureauToEnterpriseTransferDetail, "bureau_to_enterprise",
     { bureau_public_id: "source-bureau" },
     { source_bureau_public_id: "source-bureau", destination_enterprise_public_id: "target-enterprise" },],
    [AvatarBureauOwnershipPeriod, AvatarBureauToBureauTransferDetail, "bureau_to_bureau",
     { bureau_public_id: "source-bureau" },
     { source_bureau_public_id: "source-bureau", destination_bureau_public_id: "target-bureau" },],
  ].each do |period_class, detail_class, operation_kind, owner_attributes, detail_attributes|
    test "#{operation_kind} preserves its referenced ownership period on application and direct deletion" do
      AvatarRecord.transaction do
        handle = Handle.create!(handle: "source-retention-#{operation_kind}", cooldown_until: Time.current)
        avatar = Avatar.create!(active_handle: handle, capability: AvatarCapability.find(AvatarCapability::NORMAL))
        period = period_class.create!(avatar: avatar, valid_from: avatar.created_at, **owner_attributes)
        reservation = AvatarTransferReservation.create!(
          avatar: avatar, operation_kind: operation_kind,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a31",
          request_fingerprint: "source-retention-probe",
        )
        detail = detail_class.create!(
          transfer_reservation: reservation, source_ownership_period: period,
          request_actor_public_id: "source-actor", **detail_attributes,
        )

        assert_not period.destroy
        assert_not_empty period.errors[:base]
        assert period_class.exists?(period.id)
        assert detail_class.exists?(detail.id)

        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.transaction(requires_new: true) { period.delete }
        end
        assert period_class.exists?(period.id)
        assert detail_class.exists?(detail.id)
        raise ActiveRecord::Rollback
      end
    end
  end
end
