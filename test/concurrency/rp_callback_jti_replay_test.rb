# frozen_string_literal: true

require "test_helper"
require "timeout"

class RpCallbackJtiReplayTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "concurrent callbacks consume one ID Token jti exactly once" do
    cell = RpCellBinding.fetch("rp_base_app")
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    issuer = Oidc::AcmeServiceOrigin.from_configured_host(hosts.visa_service.host, default_scheme: "https").origin
    suffix = SecureRandom.uuid
    subject = "callback-subject-#{suffix}"
    sid = "callback-sid-#{suffix}"
    jti_digest = Digest::SHA256.hexdigest("callback-jti-#{suffix}")
    arguments = {
      cell:,
      issuer:,
      subject:,
      sid:,
      absolute_expires_at: 1.hour.from_now,
      id_token_jti_digest: jti_digest,
      id_token_expires_at: 2.minutes.from_now,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => Time.current.to_i,
        "id_token_jti_digest" => jti_digest,
      },
    }
    ready = Queue.new
    start = Queue.new
    threads =
      2.times.map do
        Thread.new do
          RpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            ready << true
            start.pop
            RpCallbackCommitter.call(**arguments).outcome
          end
        rescue StandardError => e
          e
        end
      end
    2.times { Timeout.timeout(10) { ready.pop } }
    2.times { start << true }
    outcomes = threads.map { |thread| Timeout.timeout(15) { thread.value } }

    outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }

    assert_equal({ committed: 1, replayed: 1 }, outcomes.tally)
    assert_equal 1, RpBaseAppConsumedIdTokenJti.where(jti_digest:).count
    assert_equal 1, RpBaseAppSession.joins(:op_session_binding).where(rp_op_session_bindings: { sid: }).count
  ensure
    threads&.each { |thread| thread.join(5) }
    cleanup_callback_records(issuer:, sid:, subject:, jti_digest:) if issuer && sid && subject && jti_digest
  end

  private

  def cleanup_callback_records(issuer:, sid:, subject:, jti_digest:)
    RpBaseAppRecord.connected_to(role: :writing) do
      RpBaseAppConsumedIdTokenJti.where(jti_digest:).delete_all
      binding = RpBaseAppOpSessionBinding.find_by(issuer:, sid:)
      return unless binding

      identity = RpBaseAppIdentityBinding.find_by(id: binding.identity_binding_id)
      principal_id = identity&.principal_id
      RpBaseAppSession.where(op_session_binding_id: binding.id).delete_all
      binding.delete
      RpBaseAppIdentityBinding.where(subject:, issuer:).delete_all
      RpBaseAppPrincipal.where(id: principal_id).delete_all if principal_id
    end
  end
end
