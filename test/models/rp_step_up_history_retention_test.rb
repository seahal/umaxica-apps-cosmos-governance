# frozen_string_literal: true

require "test_helper"

class RpStepUpHistoryRetentionTest < ActiveSupport::TestCase
  [
    [RpStepUpState, RpStepUpStateTransition, RpStepUpStateStatus, RpBaseAppPrincipal,
     RpBaseAppIdentityBinding, RpBaseAppOpSessionBinding, RpBaseAppSession, "APP",],
    [RpBaseOrgStepUpState, RpBaseOrgStepUpStateTransition, RpBaseOrgStepUpStateStatus, RpBaseOrgPrincipal,
     RpBaseOrgIdentityBinding, RpBaseOrgOpSessionBinding, RpBaseOrgSession, "ORG",],
  ].each do |state_type, transition_type, status_type, actor_type, identity_type, binding_type, session_type, realm|
    test "#{state_type.name} preserves its transition history under both destroy and direct SQL deletion" do
      now = Time.utc(2026, 11, 12, 12)
      principal = actor_type.create!
      identity = identity_type.create!(
        principal: principal, issuer: "https://issuer.example", realm: session_type::REALM,
        client_id: session_type::CLIENT_ID, subject: "history-subject",
      )
      binding = binding_type.create!(
        identity_binding: identity, issuer: identity.issuer, realm: identity.realm,
        client_id: identity.client_id, sid: "history-session",
      )
      session = session_type.create!(op_session_binding: binding, absolute_expires_at: now + 1.day)
      state = state_type.create!(
        public_id: "123456789abcdefghijkl", rp_session: session,
        state_digest: Digest::SHA256.hexdigest("history-state"),
        browser_binding_digest: Digest::SHA256.hexdigest("history-browser"),
        nonce_digest: Digest::SHA256.hexdigest("history-nonce"),
        pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        pkce_verifier_ciphertext: "encrypted-verifier", issuer: identity.issuer,
        realm: realm, client_id: identity.client_id, return_target: "/settings/security",
        initiating_generation: 0, state_id: status_type::PENDING, expires_at: now + 15.minutes,
      )
      transition = transition_type.create!(
        owner: state, from_state_id: status_type::PENDING, to_state_id: status_type::DISPATCHING,
        reason_code: "dispatch_started", occurred_at: now,
      )

      assert_not state.destroy
      assert state.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          state_type.transaction(requires_new: true) { state_type.where(id: state.id).delete_all }
        end

      assert_kind_of PG::RestrictViolation, error.cause
      assert_equal "23001", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      assert_equal "fk_rails_42bc1ac3a0", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      assert state_type.exists?(state.id)
      assert transition_type.exists?(transition.id)
      assert_equal [transition.id], state.reload.transitions.where(to_state_id: status_type::DISPATCHING).pluck(:id)
    end
  end

  [
    [RpStepUpAuditOutbox, RpStepUpAuditOutboxAttempt, RpStepUpAuditOutboxDeliveryState, "APP", "base-app-ww"],
    [RpBaseOrgStepUpAuditOutbox, RpBaseOrgStepUpAuditOutboxAttempt,
     RpBaseOrgStepUpAuditOutboxDeliveryState, "ORG", "base-org-ww",],
  ].each do |outbox_model, attempt_model, delivery_state_type, realm, client_id|
    test "#{outbox_model.name} retains delivery attempts under both destroy and direct SQL deletion" do
      now = Time.utc(2026, 11, 12, 12)
      outbox = outbox_model.create!(
        event_uuid: "00000000-0000-4000-8000-000000000401", event_type: "step_up.requested",
        realm: realm, client_id: client_id, subject_ref: "history-subject",
        context_ref: "123456789abcdefghijk", reason_code: "requested",
        payload: { rp_state_ref: "123456789abcdefghijk", return_target_kind: "relative" },
        occurred_at: now, delivery_state_id: delivery_state_type::PENDING,
      )
      attempt = attempt_model.create!(
        outbox: outbox, attempt_number: 1, attempted_at: now,
        outcome: "failed", failure_code: "chronicle_unavailable",
      )

      assert_not outbox.destroy
      assert outbox.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          outbox_model.transaction(requires_new: true) { outbox_model.where(id: outbox.id).delete_all }
        end

      assert_kind_of PG::RestrictViolation, error.cause
      assert_equal "23001", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      assert_equal "fk_rails_9735bc9c9b", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      assert_equal [outbox.id],
                   outbox_model.where(delivery_state_id: delivery_state_type::PENDING).order(:id).pluck(:id)
      assert_equal [attempt.id], outbox.reload.attempts.order(:attempt_number).pluck(:id)
      assert_equal "chronicle_unavailable", attempt.reload.failure_code
    end
  end
end
