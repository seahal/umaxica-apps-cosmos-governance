# frozen_string_literal: true

require "test_helper"

class CoreBridgeCardinalityTest < ActiveSupport::TestCase
  CLIENT_OTHER_DELETION_ASSOCIATIONS = %i(
    client_external_identities client_apple_notification_events client_emails client_telephones
    client_totp_credentials client_passkeys client_withdrawal_ceremonies
    client_memberships clients client_banners client_members client_member_discoveries
    client_member_observations client_member_revocations client_member_impersonations client_member_suspensions
    client_member_deletions owned_members client_bulletins rp_account authority_lock client_preference
  ).freeze
  OPERATOR_OTHER_DELETION_ASSOCIATIONS = %i(
    staff_passkeys staff_secret_credentials
    staff_operators operator_workspace_accounts staff_bulletins staff_banners rp_account authority_lock
    operator_preference
  ).freeze

  test "Client exposes both bridges for distinct RP identities" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-a")
    second = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-b")

    assert_equal [first.id, second.id], actor.core_app_client_bridges.order(:id).pluck(:id)
    assert_equal actor, first.client
    assert_equal actor, second.client
  end

  test "Client rejects duplicate actor and RP pairs in Model and database" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-a")
    duplicate = CoreAppClientBridge.new(client: actor, rp_client_id: "cardinality-a")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:client_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Client.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    assert CoreAppClientBridge.exists?(first.id)
    assert_equal 1, CoreAppClientBridge.where(client: actor, rp_client_id: "cardinality-a").count
  end

  test "Client deletes every bridge when preloaded" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    first = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-a")
    second = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-b")
    actor = Client.includes(*CLIENT_OTHER_DELETION_ASSOCIATIONS, :core_app_client_bridges).find(actor.id)

    actor.destroy!

    assert_not Client.exists?(actor.id)
    assert_not CoreAppClientBridge.exists?(first.id)
    assert_not CoreAppClientBridge.exists?(second.id)
  end

  test "Client deletes every bridge when unloaded for a caller permitting lazy loading" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    first = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-a")
    second = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-b")
    actor = Client.includes(CLIENT_OTHER_DELETION_ASSOCIATIONS).find(actor.id)
    actor.strict_loading!(false)

    actor.destroy!

    assert_not Client.exists?(actor.id)
    assert_not CoreAppClientBridge.exists?(first.id)
    assert_not CoreAppClientBridge.exists?(second.id)
  end

  test "Operator exposes both bridges for distinct RP identities" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-a")
    second = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-b")

    assert_equal [first.id, second.id], actor.core_org_operator_bridges.order(:id).pluck(:id)
    assert_equal actor, first.operator
    assert_equal actor, second.operator
  end

  test "Operator rejects duplicate actor and RP pairs in Model and database" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-a")
    duplicate = CoreOrgOperatorBridge.new(operator: actor, rp_client_id: "cardinality-a")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:operator_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Operator.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    assert CoreOrgOperatorBridge.exists?(first.id)
    assert_equal 1, CoreOrgOperatorBridge.where(operator: actor, rp_client_id: "cardinality-a").count
  end

  test "Operator deletes every bridge when preloaded" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    first = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-a")
    second = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-b")
    actor = Operator.includes(*OPERATOR_OTHER_DELETION_ASSOCIATIONS, :core_org_operator_bridges).find(actor.id)

    actor.destroy!

    assert_not Operator.exists?(actor.id)
    assert_not CoreOrgOperatorBridge.exists?(first.id)
    assert_not CoreOrgOperatorBridge.exists?(second.id)
  end

  test "Operator deletes every bridge when unloaded for a caller permitting lazy loading" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    first = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-a")
    second = CoreOrgOperatorBridge.create!(operator: actor, rp_client_id: "cardinality-b")
    actor = Operator.includes(OPERATOR_OTHER_DELETION_ASSOCIATIONS).find(actor.id)
    actor.strict_loading!(false)

    actor.destroy!

    assert_not Operator.exists?(actor.id)
    assert_not CoreOrgOperatorBridge.exists?(first.id)
    assert_not CoreOrgOperatorBridge.exists?(second.id)
  end

  test "recoverable Client deletion preserves both RP bridges" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-a")
    second = CoreAppClientBridge.create!(client: actor, rp_client_id: "cardinality-b")
    actor = Client.includes(*CLIENT_OTHER_DELETION_ASSOCIATIONS, :core_app_client_bridges).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert CoreAppClientBridge.exists?(first.id)
    assert CoreAppClientBridge.exists?(second.id)
  end
end
