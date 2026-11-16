# frozen_string_literal: true

require "test_helper"

class RegistrationCompletionUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a persisted completion method is read-only" do
    method = ClientRegistrationCompletionMethod.find_by!(key: "email")

    assert_predicate method, :readonly?
    assert_not_predicate ClientRegistrationCompletionMethod.new(key: "email"), :readonly?
  end

  test "completion catalog rejects an existing key before attempting its immutable insert" do
    method = ClientRegistrationCompletionMethod.new(id: 1, key: "email")

    assert_not method.valid?
    assert method.errors.of_kind?(:key, :taken)
  end

  test "completion remains associated with its owner and prevents direct owner deletion" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    completion = ClientRegistrationCompletion.create!(
      client: client, method_id: 1, public_id: PublicId.generate,
      sign_up_flow_ref: PublicId.generate, completed_at: Client.database_now,
    )

    assert_includes client.registration_completions, completion
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) { Client.where(id: client.id).delete_all }
      end

    assert_kind_of PG::RestrictViolation, error.cause
    assert_predicate completion.reload, :persisted?
  end

  test "completion preflight keeps client reference and signup reference independently unique" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    another = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    completed = ClientRegistrationCompletion.create!(
      client: client, method_id: 1, public_id: PublicId.generate,
      sign_up_flow_ref: PublicId.generate, completed_at: Client.database_now,
    )
    [
      [:client_id, client.id], [:public_id, completed.public_id], [:sign_up_flow_ref, completed.sign_up_flow_ref],
    ].each do |column, value|
      candidate = ClientRegistrationCompletion.new(
        client: another, method_id: 1, public_id: PublicId.generate,
        sign_up_flow_ref: PublicId.generate, completed_at: Client.database_now,
      )
      candidate[column] = value

      assert_not candidate.valid?
      assert candidate.errors.of_kind?(column, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        ClientRegistrationCompletion.transaction(requires_new: true) { candidate.save!(validate: false) }
      end
    end
    assert_equal 1, ClientRegistrationCompletion.where(client_id: client.id).count
    assert_predicate completed.reload, :readonly?
  end

  test "unchanged durable completion validation performs no receipt uniqueness probe" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    completed = ClientRegistrationCompletion.create!(
      client: client, method_id: 1, public_id: PublicId.generate,
      sign_up_flow_ref: PublicId.generate, completed_at: Client.database_now,
    )
    queries = []
    subscriber =
      ->(_name, _start, _finish, _id, payload) {
        queries << payload[:sql] if payload[:sql].match?(/SELECT.*client_registration_completions/i)
      }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { completed.valid? }

    assert_empty queries
  end
end
