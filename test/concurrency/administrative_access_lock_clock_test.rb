# frozen_string_literal: true

require "test_helper"
require "timeout"

class AdministrativeAccessLockClockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "lock sets the token cutoff after obtaining the account lock despite unavailable delivery" do
    account = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    ready = Queue.new
    worker = nil
    marker = nil

    account.with_lock do
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            current = Client.find(account.id)
            AdministrativeAccessLock.lock!(account: current, operator:, reason_code: "security_incident")
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            Client.uncached do
              Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
            end
          break if blocked

          Thread.pass
        end
      end
      marker = Client.database_now
    end
    assert_raises(AccessOpDataUnavailableError) { Timeout.timeout(10) { worker.value } }

    assert_operator account.reload.token_valid_after_at, :>=, marker
  ensure
    begin
      worker&.join(10)
    rescue AccessOpDataUnavailableError
      # The public worker refusal has already been asserted.
    end
    AccountAccessEvent.where(account_type: "Client", account_id: account.id).delete_all if account
    AppIdentityAuthenticationEvent.where(actor_ref: account.id.to_s).delete_all if account
    account&.delete
    operator&.delete
  end
end
