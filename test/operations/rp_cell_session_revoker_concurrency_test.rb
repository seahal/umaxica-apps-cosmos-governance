# frozen_string_literal: true

require "test_helper"
require "timeout"

class RpCellSessionRevokerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "a concurrent JTI winner for another sid returns conflict after the losing anchor rolls back" do
    cell = RpCellBinding.fetch("rp_base_app")
    issuer = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    ).origin
    jti = "base-app-race-#{SecureRandom.hex(12)}"
    sids = ["base-app-race-first-#{SecureRandom.hex(8)}", "base-app-race-second-#{SecureRandom.hex(8)}"]
    now = Time.current.to_i
    payloads =
      sids.map do |sid|
        {
          "iss" => issuer,
          "aud" => [cell.client_id],
          "iat" => now,
          "exp" => now + 120,
          "jti" => jti,
          "sid" => sid,
          "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
        }
      end
    ready = Queue.new
    release = Queue.new
    gate_mutex = Mutex.new
    gates_remaining = 2
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        next unless payload[:name] == "RpBaseAppEventReceipt Load"
        next unless payload[:sql].include?("rp_event_receipts")

        should_gate =
          gate_mutex.synchronize do
            if gates_remaining.positive?
              gates_remaining -= 1
              true
            else
              false
            end
          end
        next unless should_gate

        ready << true
        release.pop
      end
    threads = []

    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      payloads.map do |payload|
        Thread.new do
          RpBaseAppRecord.connection_pool.with_connection do
            RpCellSessionRevoker.call(cell:, payload:)
          end
        rescue RpCellSessionRevoker::EventConflict
          :conflict
        rescue StandardError => e
          e
        end
      end

    begin
      2.times { Timeout.timeout(10) { ready.pop } }
    ensure
      2.times { release << true }
    end
    results = threads.map(&:value)
    errors = results.grep(StandardError)

    assert_empty errors.map(&:class).map(&:name)
    assert_equal 1, results.count(:revoked)
    assert_equal 1, results.count(:conflict)
    assert_equal 1, RpBaseAppEventReceipt.where(
      issuer:, realm: cell.realm, client_id: cell.client_id,
      event_type: RpCellSessionRevoker::RECEIPT_EVENT_TYPE,
      jti_digest: Digest::SHA256.digest(jti),
    ).count
    assert_equal 1,
                 RpBaseAppOpSessionBinding.where(issuer:, realm: cell.realm, client_id: cell.client_id, sid: sids).count
  ensure
    2.times { release << true } if release
    threads&.each(&:join)
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    RpBaseAppEventReceipt.where(jti_digest: Digest::SHA256.digest(jti)).delete_all if defined?(jti)
    RpBaseAppOpSessionBinding.where(sid: sids).delete_all if defined?(sids)
  end
end
