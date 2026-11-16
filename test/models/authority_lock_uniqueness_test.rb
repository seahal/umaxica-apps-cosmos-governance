# frozen_string_literal: true

require "test_helper"

class AuthorityLockUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ordinary duplicates have owner errors while public acquisition remains idempotent on both surfaces" do
    [[Client, ClientAuthorityLock, :client_id],
     [Operator, OperatorAuthorityLock, :operator_id],].each do |actor_class, lock_class, owner_key|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      first = lock_class.acquire_for!(**{ owner_key => actor.id })
      candidate = lock_class.new(owner_key => actor.id)

      assert_not candidate.valid?
      assert candidate.errors.of_kind?(owner_key, :taken)
      assert_equal first.id, lock_class.acquire_for!(**{ owner_key => actor.id }).id
      assert_equal 1, lock_class.where(owner_key => actor.id).count
      assert first.created_at
      assert first.updated_at
      assert_raises(ActiveRecord::RecordNotUnique) do
        lock_class.transaction(requires_new: true) { candidate.save!(validate: false) }
      end
    end
  end

  test "public acquisition rejects nil and absent owners without a retained lock" do
    [[ClientAuthorityLock, :client_id], [OperatorAuthorityLock, :operator_id]].each do |lock_class, owner_key|
      [nil, -1].each do |value|
        assert_no_difference -> { lock_class.count } do
          assert_raises(ActiveRecord::RecordInvalid) { lock_class.acquire_for!(**{ owner_key => value }) }
        end
      end
    end
  end
  test "unchanged persisted authority lock validation adds no uniqueness query" do
    [[Client, ClientAuthorityLock, :client_id],
     [Operator, OperatorAuthorityLock, :operator_id],].each do |actor_class, lock_class, owner_key|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      lock = lock_class.acquire_for!(**{ owner_key => actor.id })
      queries = []
      lock_probe = /SELECT.*(?:client|operator)_authority_locks/i
      subscriber =
        ->(_name, _start, _finish, _id, payload) {
          queries << payload[:sql] if payload[:sql].match?(lock_probe)
        }

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { assert_predicate lock, :valid? }

      assert_empty queries
    end
  end
end
