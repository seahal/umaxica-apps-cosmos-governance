# frozen_string_literal: true

require "test_helper"

class ActorAttributionRetentionTest < ActiveSupport::TestCase
  CLIENT_DELETION_ASSOCIATIONS = %i(
    client_external_identities client_apple_notification_events client_emails client_telephones
    client_totp_credentials client_passkeys client_withdrawal_ceremonies
    client_memberships clients client_banners client_members client_member_discoveries
    client_member_observations client_member_revocations client_member_impersonations client_member_suspensions
    client_member_deletions owned_members client_bulletins rp_account authority_lock core_app_client_bridges
    client_preference
  ).freeze
  OPERATOR_DELETION_ASSOCIATIONS = %i(
    staff_passkeys staff_secret_credentials
    staff_operators operator_workspace_accounts staff_bulletins staff_banners rp_account authority_lock
    operator_preference core_org_operator_bridges
  ).freeze

  test "enterprise transfer preserves its source client attribution" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    resource = Enterprise.create!(name: "Attribution", title: "Attrib")
    request = EnterpriseOwnershipTransferRequest.create!(
      enterprise: resource, source_client: actor, destination_client: peer,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
    )
    bulletin = ClientBulletin.create!(user: actor, title: "Retain on refusal")
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert EnterpriseOwnershipTransferRequest.exists?(request.id)
    assert ClientBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "enterprise_ownership_transfer_requests"
  end

  test "enterprise transfer preserves its destination client attribution after cancellation" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    resource = Enterprise.create!(name: "Attribution", title: "Attrib")
    request = EnterpriseOwnershipTransferRequest.create!(
      enterprise: resource, source_client: peer, destination_client: actor,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
      status: "cancelled", cancelled_at: now,
    )
    bulletin = ClientBulletin.create!(user: actor, title: "Retain on refusal")
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert EnterpriseOwnershipTransferRequest.exists?(request.id)
    assert ClientBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "enterprise_ownership_transfer_requests"
  end

  test "client_persona transfer preserves its source client attribution" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    ClientIdentityState.ensure_defaults!
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test", subject: "client_persona-source", audience: "attribution-test",
      source_record_id: 900_001, status_id: ClientIdentityState::ACTIVE,
    )
    resource = ClientPersona.create!(client_identity: identity, title: "Attrib")
    request = ClientPersonaOwnershipTransferRequest.create!(
      client_persona: resource, source_client: actor, destination_client: peer,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
    )
    bulletin = ClientBulletin.create!(user: actor, title: "Retain on refusal")
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert ClientPersonaOwnershipTransferRequest.exists?(request.id)
    assert ClientBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "client_persona_ownership_transfer_requests"
  end

  test "client_persona transfer preserves its destination client attribution after cancellation" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    ClientIdentityState.ensure_defaults!
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test", subject: "client_persona-destination", audience: "attribution-test",
      source_record_id: 900_001, status_id: ClientIdentityState::ACTIVE,
    )
    resource = ClientPersona.create!(client_identity: identity, title: "Attrib")
    request = ClientPersonaOwnershipTransferRequest.create!(
      client_persona: resource, source_client: peer, destination_client: actor,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
      status: "cancelled", cancelled_at: now,
    )
    bulletin = ClientBulletin.create!(user: actor, title: "Retain on refusal")
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert ClientPersonaOwnershipTransferRequest.exists?(request.id)
    assert ClientBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "client_persona_ownership_transfer_requests"
  end

  test "bureau transfer preserves its source operator attribution" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    resource = Bureau.create!(name: "Attribution", title: "Attrib")
    request = BureauOwnershipTransferRequest.create!(
      bureau: resource, source_operator: actor, destination_operator: peer,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert BureauOwnershipTransferRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "bureau_ownership_transfer_requests"
  end

  test "bureau transfer preserves its destination operator attribution after cancellation" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    resource = Bureau.create!(name: "Attribution", title: "Attrib")
    request = BureauOwnershipTransferRequest.create!(
      bureau: resource, source_operator: peer, destination_operator: actor,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
      status: "cancelled", cancelled_at: now,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert BureauOwnershipTransferRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "bureau_ownership_transfer_requests"
  end

  test "agent transfer preserves its source operator attribution" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    OperatorIdentityState.ensure_defaults!
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test", subject: "agent-source", audience: "attribution-test",
      source_record_id: 900_001, status_id: OperatorIdentityState::ACTIVE,
    )
    resource = Agent.create!(operator_identity: identity, title: "Attrib")
    request = AgentOwnershipTransferRequest.create!(
      agent: resource, source_operator: actor, destination_operator: peer,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert AgentOwnershipTransferRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "agent_ownership_transfer_requests"
  end

  test "agent transfer preserves its destination operator attribution after cancellation" do
    now = Time.current
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    OperatorIdentityState.ensure_defaults!
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test", subject: "agent-destination", audience: "attribution-test",
      source_record_id: 900_001, status_id: OperatorIdentityState::ACTIVE,
    )
    resource = Agent.create!(operator_identity: identity, title: "Attrib")
    request = AgentOwnershipTransferRequest.create!(
      agent: resource, source_operator: peer, destination_operator: actor,
      expected_ownership_revision: 0, requested_at: now, expires_at: now + 1.hour,
      status: "cancelled", cancelled_at: now,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert AgentOwnershipTransferRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "agent_ownership_transfer_requests"
  end

  test "lifecycle request preserves target attribution" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "suspend", status: "pending", target_operator: actor,
      requested_by_operator: peer,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert OperatorLifecycleRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "operator_lifecycle_requests"
  end

  test "lifecycle request preserves requester attribution" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "suspend", status: "pending", target_operator: peer,
      requested_by_operator: actor,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert OperatorLifecycleRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "operator_lifecycle_requests"
  end

  test "lifecycle request preserves approver attribution" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "suspend", status: "approved", target_operator: peer,
      requested_by_operator: peer,
      approved_by_operator: actor,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert OperatorLifecycleRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "operator_lifecycle_requests"
  end

  test "lifecycle request preserves rejector attribution" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "suspend", status: "rejected", target_operator: peer,
      requested_by_operator: peer,
      rejected_by_operator: actor,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert OperatorLifecycleRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "operator_lifecycle_requests"
  end

  test "lifecycle request preserves executor attribution" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    peer = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "suspend", status: "executed", target_operator: peer,
      requested_by_operator: peer,
      executed_by_operator: actor,
    )
    bulletin = OperatorBulletin.create!(staff: actor, title: "Retain on refusal")
    actor = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Operator.exists?(actor.id)
    assert OperatorLifecycleRequest.exists?(request.id)
    assert OperatorBulletin.exists?(bulletin.id)
    database_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Operator.transaction(requires_new: true) do
          bulletin.delete
          actor.delete
        end
      end
    assert_includes database_error.message, "operator_lifecycle_requests"
  end

  test "absent optional lifecycle actors do not prevent deleting an unrelated operator" do
    requester = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    unrelated = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    request = OperatorLifecycleRequest.create!(
      action: "join", requested_by_operator: requester, target_email: "new@example.test", organization_id: 1,
    )
    unrelated = Operator.includes(OPERATOR_DELETION_ASSOCIATIONS).find(unrelated.id)

    assert_nil request.target_operator_id
    assert_nil request.approved_by_operator_id
    assert_nil request.rejected_by_operator_id
    assert_nil request.executed_by_operator_id
    assert unrelated.destroy
    assert_not Operator.exists?(unrelated.id)
    assert OperatorLifecycleRequest.exists?(request.id)
  end
end
