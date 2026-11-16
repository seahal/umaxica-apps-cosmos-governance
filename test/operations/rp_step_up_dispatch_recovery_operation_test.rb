# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class RpStepUpDispatchRecoveryOperationTest < ActiveSupport::TestCase
  include RpCellSessionHelper

  self.fixture_table_names = []

  test "expired pending and dispatching states transition once with durable audit records" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    cell = RpCellBinding.fetch("rp_base_app")
    now = RpBaseAppRecord.database_now
    session = seed_rp_cell_session(
      cell:,
      issuer: OidcIssuer.for_resource_type("client"),
      subject: OidcSubject.for(actor, resource_type: "client"),
      sid: SecureRandom.uuid,
      absolute_expires_at: now + 1.hour,
    )

    pending_state = RpStepUpState.create!(
      public_id: PublicId.generate,
      rp_session: session,
      state_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      browser_binding_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      pkce_challenge: OidcPkce.challenge_for(SecureRandom.urlsafe_base64(32)),
      pkce_verifier_ciphertext: StepUpPkceVerifierCipherAdapter.encrypt(verifier: SecureRandom.urlsafe_base64(32)),
      issuer: OidcIssuer.for_resource_type("client"),
      realm: cell.realm.upcase,
      client_id: cell.client_id,
      return_target: "/settings/birthdate",
      initiating_generation: session.installed_generation,
      state_id: RpStepUpStateStatus::PENDING,
      expires_at: now - 1.second,
    )
    dispatching_state = RpStepUpState.create!(
      public_id: PublicId.generate,
      rp_session: session,
      state_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      browser_binding_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      nonce_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      pkce_challenge: OidcPkce.challenge_for(SecureRandom.urlsafe_base64(32)),
      pkce_verifier_ciphertext: StepUpPkceVerifierCipherAdapter.encrypt(verifier: SecureRandom.urlsafe_base64(32)),
      issuer: OidcIssuer.for_resource_type("client"),
      realm: cell.realm.upcase,
      client_id: cell.client_id,
      return_target: "/settings/birthdate",
      initiating_generation: session.installed_generation,
      state_id: RpStepUpStateStatus::DISPATCHING,
      expires_at: now + 5.minutes,
    )
    RpStepUpStateTransition.create!(
      owner: dispatching_state,
      from_state_id: RpStepUpStateStatus::PENDING,
      to_state_id: RpStepUpStateStatus::DISPATCHING,
      reason_code: "dispatch_started",
      occurred_at: now - RpStepUpDispatchRecoveryOperation::DISPATCH_DEADLINE - 1.second,
    )

    assert_equal 2, RpStepUpDispatchRecoveryOperation.call(cell:)

    assert_equal RpStepUpStateStatus::EXPIRED, pending_state.reload.state_id
    assert_equal RpStepUpStateStatus::INDETERMINATE, dispatching_state.reload.state_id
    assert_equal ["expired"], pending_state.transitions.order(:id).pluck(:reason_code)
    assert_equal ["dispatch_started", "dispatch_deadline_passed"],
                 dispatching_state.transitions.order(:id).pluck(:reason_code)
    assert_equal %w(step_up.expired step_up.indeterminate),
                 RpStepUpAuditOutbox.where(context_ref: [pending_state.public_id, dispatching_state.public_id])
                   .order(:event_type).pluck(:event_type)
  end
end
