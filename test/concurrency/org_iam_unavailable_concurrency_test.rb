# frozen_string_literal: true

require "test_helper"
require "timeout"

class OrgIamUnavailableConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "concurrent IAM requests cannot authorize or mutate without Access proof" do
    before_grants = OperatorCapabilityGrant.order(:id).map(&:attributes)
    before_outcomes = OrgIamOperationOutcome.order(:id).map(&:attributes)
    ready = Queue.new
    proceed = Queue.new
    mutations = Queue.new
    workers =
      2.times.map do
        Thread.new do
          ready << true
          proceed.pop
          begin
            OrgIamPrincipalCommitter.call(
              actor: nil, token: nil, evidence: nil, operation_id: SecureRandom.uuid,
              operation_kind: "grant", subject_public_id: "untrusted-subject", request_digest: "untrusted",
              authorize: ->(_actor) {
                mutations << :authorization
                true
              },
            ) { mutations << :mutation }
          rescue AccessOpDataUnavailableError => e
            e
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    2.times { Timeout.timeout(10) { ready.pop } }
    2.times { proceed << true }

    workers.each { |worker| assert_instance_of AccessOpDataUnavailableError, Timeout.timeout(10) { worker.value } }

    assert_empty mutations
    assert_equal before_grants, OperatorCapabilityGrant.order(:id).map(&:attributes)
    assert_equal before_outcomes, OrgIamOperationOutcome.order(:id).map(&:attributes)
  ensure
    2.times { proceed << true } if proceed
    workers&.each { |worker| worker.join(10) }
  end
end
