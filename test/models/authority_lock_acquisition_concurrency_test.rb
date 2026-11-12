# frozen_string_literal: true

require "test_helper"

class AuthorityLockAcquisitionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "concurrent first acquisition on either surface returns one committed owner lock" do
    [[Client, ClientAuthorityLock, :client_id],
     [Operator, OperatorAuthorityLock, :operator_id],].each do |actor_class, lock_class, owner_key|
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      ready = Queue.new
      start = Queue.new
      workers =
        2.times.map do
          Thread.new do
            lock_class.connection_pool.with_connection do
              ready << true
              start.pop
              lock_class.transaction { lock_class.acquire_for!(**{ owner_key => actor.id }).id }
            end
          end
        end
      2.times { ready.pop }
      2.times { start << true }
      ids = workers.map(&:value)

      assert_equal 1, ids.uniq.length
      assert_equal 1, lock_class.where(owner_key => actor.id).count
    ensure
      workers&.each(&:join)
      if actor
        lock_class.where(owner_key => actor.id).delete_all
        actor_class.where(id: actor.id).delete_all
      end
    end
  end
end
