# frozen_string_literal: true

require "test_helper"

class RequiredRelationshipConstraintTest < ActiveSupport::TestCase
  CLIENT_DELETION_ASSOCIATIONS = %i(
    client_external_identities client_apple_notification_events client_emails client_telephones
    client_totp_credentials client_passkeys client_withdrawal_ceremonies
    client_memberships clients client_banners client_members client_member_discoveries
    client_member_observations client_member_revocations client_member_impersonations client_member_suspensions
    client_member_deletions owned_members client_bulletins rp_account authority_lock core_app_client_bridges
    client_preference
  ).freeze

  test "ClientProfile saves a valid parent and rejects missing parent through Model and SQL" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = ClientProfile.create!(user: actor, client_status_id: 1, status_id: 1)

    assert_equal actor.id, record.reload.user_id
    record.user = nil

    assert_not record.valid?
    assert_not_empty record.errors[:user]
    assert_raises(ActiveRecord::NotNullViolation) do
      ClientProfile.transaction(requires_new: true) { ClientProfile.where(id: record.id).update_all(user_id: nil) }
    end
    assert_equal actor.id, record.reload.user_id
  end

  test "ClientProfile database rejects a nonexistent parent" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = ClientProfile.create!(user: actor, client_status_id: 1, status_id: 1)

    assert_not Client.exists?(-1)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientProfile.transaction(requires_new: true) { ClientProfile.where(id: record.id).update_all(user_id: -1) }
    end
    assert_equal actor.id, record.reload.user_id
  end

  test "Member saves a valid parent and rejects missing parent through Model and SQL" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = Member.create!(user: actor, public_id: "required-member")

    assert_equal actor.id, record.reload.user_id
    record.user = nil

    assert_not record.valid?
    assert_not_empty record.errors[:user]
    assert_raises(ActiveRecord::NotNullViolation) do
      Member.transaction(requires_new: true) { Member.where(id: record.id).update_all(user_id: nil) }
    end
    assert_equal actor.id, record.reload.user_id
  end

  test "Member database rejects a nonexistent parent" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = Member.create!(user: actor, public_id: "required-member")

    assert_not Client.exists?(-1)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Member.transaction(requires_new: true) { Member.where(id: record.id).update_all(user_id: -1) }
    end
    assert_equal actor.id, record.reload.user_id
  end

  test "OperatorWorkspaceAccount saves a valid parent and rejects missing parent through Model and SQL" do
    actor = Department.create!(name: "Required department", department_status: department_statuses(:active))
    record = OperatorWorkspaceAccount.create!(staff: operators(:one), department: actor)

    assert_equal actor.id, record.reload.department_id
    record.department = nil

    assert_not record.valid?
    assert record.errors.of_kind?(:department, :blank)
    assert_raises(ActiveRecord::NotNullViolation) do
      OperatorWorkspaceAccount.transaction(requires_new: true) {
        OperatorWorkspaceAccount.where(id: record.id).update_all(department_id: nil)
      }
    end
    assert_equal actor.id, record.reload.department_id
  end

  test "OperatorWorkspaceAccount database rejects a nonexistent parent" do
    actor = Department.create!(name: "Required department", department_status: department_statuses(:active))
    record = OperatorWorkspaceAccount.create!(staff: operators(:one), department: actor)

    assert_not Department.exists?(-1)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      OperatorWorkspaceAccount.transaction(requires_new: true) {
        OperatorWorkspaceAccount.where(id: record.id).update_all(department_id: -1)
      }
    end
    assert_equal actor.id, record.reload.department_id
  end

  test "ClientProfile retains parent and child until explicit child cleanup" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    record = ClientProfile.create!(user: actor, client_status_id: 1, status_id: 1)
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert ClientProfile.exists?(record.id)
    assert_equal actor.id, record.reload.user_id
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) { actor.delete }
      end
    assert_equal "fk_client_profiles_on_user_id", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    record.strict_loading!(false)
    record.destroy!
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)
    actor.destroy!

    assert_not ClientProfile.exists?(record.id)
    assert_not Client.exists?(actor.id)
  end

  test "Member retains parent and child until explicit child cleanup" do
    now = Time.current
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      created_at: now - 3.days, discard_at: now - 2.days, purge_eligible_at: now - 1.day,
    )
    record = Member.create!(user: actor, public_id: "required-member")
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Client.exists?(actor.id)
    assert Member.exists?(record.id)
    assert_equal actor.id, record.reload.user_id
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) { actor.delete }
      end
    assert_equal "fk_rails_2e88fb7ce9", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    record.strict_loading!(false)
    record.destroy!
    actor = Client.includes(CLIENT_DELETION_ASSOCIATIONS).find(actor.id)
    actor.destroy!

    assert_not Member.exists?(record.id)
    assert_not Client.exists?(actor.id)
  end

  test "OperatorWorkspaceAccount retains parent and child until explicit child cleanup" do
    actor = Department.create!(name: "Retained department", department_status: department_statuses(:active))
    record = OperatorWorkspaceAccount.create!(staff: operators(:one), department: actor)

    assert_not actor.destroy
    assert_not_empty actor.errors[:base]
    assert Department.exists?(actor.id)
    assert OperatorWorkspaceAccount.exists?(record.id)
    assert_equal actor.id, record.reload.department_id
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Department.transaction(requires_new: true) { actor.delete }
      end
    assert_equal "fk_operator_workspace_accounts_on_department_id", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    record.strict_loading!(false)
    record.destroy!
    actor.reload
    actor.destroy!

    assert_not OperatorWorkspaceAccount.exists?(record.id)
    assert_not Department.exists?(actor.id)
  end
end
