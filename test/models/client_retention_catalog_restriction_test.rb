# frozen_string_literal: true

require "test_helper"

class ClientRetentionCatalogRestrictionTest < ActiveSupport::TestCase
  test "referenced retention hold status rejects application and direct deletion" do
    ClientRetentionHoldStatus.ensure_defaults!
    hold = ClientRetentionHold.create!(client: clients(:one), applied_at: Time.utc(2026, 11, 12))
    status = hold.status

    assert_not status.destroy
    assert_not_empty status.errors[:base]
    assert ClientRetentionHold.exists?(hold.id)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AppZenithRecord.transaction(requires_new: true) { status.delete }
    end
    assert ClientRetentionHoldStatus.exists?(status.id)
  end

  test "referenced privacy request status rejects application and direct deletion" do
    ClientPrivacyRequestStatus.ensure_defaults!
    request = ClientPrivacyRequest.create!(
      client: clients(:one), received_at: Time.utc(2026, 11, 12), response_due_at: Time.utc(2026, 12, 12),
    )
    status = request.status

    assert_not status.destroy
    assert_not_empty status.errors[:base]
    assert ClientPrivacyRequest.exists?(request.id)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AppZenithRecord.transaction(requires_new: true) { status.delete }
    end
    assert ClientPrivacyRequestStatus.exists?(status.id)
  end

  test "referenced processor notification status rejects application and direct deletion" do
    ClientPrivacyRequestStatus.ensure_defaults!
    ClientProcessorErasureNotificationStatus.ensure_defaults!
    request = ClientPrivacyRequest.create!(
      client: clients(:one), received_at: Time.utc(2026, 11, 12), response_due_at: Time.utc(2026, 12, 12),
    )
    notification = ClientProcessorErasureNotification.create!(
      client_privacy_request: request, processor_key: "email_delivery", requested_at: Time.utc(2026, 11, 12),
    )
    status = notification.status

    assert_not status.destroy
    assert_not_empty status.errors[:base]
    assert ClientProcessorErasureNotification.exists?(notification.id)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AppZenithRecord.transaction(requires_new: true) { status.delete }
    end
    assert ClientProcessorErasureNotificationStatus.exists?(status.id)
  end

  test "withdrawal event preserves both source and destination status records" do
    ClientWithdrawalFlowStatus.ensure_defaults!
    flow = ClientWithdrawalFlow.create!(
      client: clients(:one), status_id: ClientWithdrawalFlowStatus::REQUESTED, began_at: Time.utc(2026, 11, 12),
    )
    event = ClientWithdrawalFlowEvent.create!(
      client_withdrawal_flow: flow, client: clients(:one),
      from_status_id: ClientWithdrawalFlowStatus::CLOSING, to_status_id: ClientWithdrawalFlowStatus::DISCARDED,
      occurred_at: Time.utc(2026, 11, 12),
    )
    source = event.from_status
    destination = event.to_status

    assert_not source.destroy
    assert_not_empty source.errors[:base]
    assert_not destination.destroy
    assert_not_empty destination.errors[:base]
    assert ClientWithdrawalFlowEvent.exists?(event.id)
    source_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppZenithRecord.transaction(requires_new: true) { source.delete }
      end
    assert_instance_of PG::RestrictViolation, source_error.cause
    destination_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AppZenithRecord.transaction(requires_new: true) { destination.delete }
      end
    assert_instance_of PG::RestrictViolation, destination_error.cause
  end
end
