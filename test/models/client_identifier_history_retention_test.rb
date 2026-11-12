# frozen_string_literal: true

require "test_helper"

class ClientIdentifierHistoryRetentionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "recoverable client retains identifier history" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmailHistory.create!(
      user: client, fingerprint: "retained-email", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    telephone = ClientTelephoneHistory.create!(
      user: client, fingerprint: "retained-phone", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )

    assert_includes client.email_histories, email
    assert_includes client.telephone_histories, telephone
    assert_not client.destroy
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) { Client.where(id: client.id).delete_all }
      end

    assert_kind_of PG::RestrictViolation, error.cause
    assert_predicate email.reload, :persisted?
    assert_predicate telephone.reload, :persisted?
  end
  test "eligible client erases preloaded history before its restrictive associations run" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    email = ClientEmailHistory.create!(
      user: client, fingerprint: "expired-email", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    telephone = ClientTelephoneHistory.create!(
      user: client, fingerprint: "expired-phone", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    client.strict_loading!(false)
    client.email_histories.load
    client.telephone_histories.load

    assert client.destroy
    assert_not ClientEmailHistory.exists?(email.id)
    assert_not ClientTelephoneHistory.exists?(telephone.id)
  end
  test "rolling back an eligible deletion restores the owner and identifier history" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    email = ClientEmailHistory.create!(
      user: client, fingerprint: "rollback-email", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    telephone = ClientTelephoneHistory.create!(
      user: client, fingerprint: "rollback-phone", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    client.strict_loading!(false)

    Client.transaction(requires_new: true) do
      assert client.destroy
      assert_not ClientEmailHistory.exists?(email.id)
      assert_not ClientTelephoneHistory.exists?(telephone.id)
      raise ActiveRecord::Rollback
    end

    assert Client.exists?(client.id)
    assert ClientEmailHistory.exists?(email.id)
    assert ClientTelephoneHistory.exists?(telephone.id)
  end
end
