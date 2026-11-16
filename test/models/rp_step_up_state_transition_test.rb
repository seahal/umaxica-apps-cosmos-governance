# frozen_string_literal: true

require "test_helper"

class RpStepUpStateTransitionTest < ActiveSupport::TestCase
  test "a transition cannot duplicate its target state for one ceremony" do
    result = seed_rp_cell_session(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-transition-subject",
      sid: "step-up-transition-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    owner = RpStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result,
      state_digest: Digest::SHA256.hexdigest("transition-state"),
      browser_binding_digest: Digest::SHA256.hexdigest("transition-browser"),
      nonce_digest: Digest::SHA256.hexdigest("transition-nonce"),
      pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      pkce_verifier_ciphertext: "ciphertext:v1:test-value",
      issuer: "https://www.umaxica.app",
      realm: "APP",
      client_id: "base-app-ww",
      return_target: "/settings/security",
      initiating_generation: 0,
      state: RpStepUpStateStatus.find(RpStepUpStateStatus::PENDING),
      expires_at: Time.utc(2099, 1, 1),
    )
    attributes = {
      owner: owner,
      from_state: RpStepUpStateStatus.find(RpStepUpStateStatus::PENDING),
      to_state: RpStepUpStateStatus.find(RpStepUpStateStatus::DISPATCHING),
      reason_code: "dispatch_started",
      occurred_at: Time.utc(2026, 11, 3, 12),
    }
    RpStepUpStateTransition.create!(attributes)

    duplicate = RpStepUpStateTransition.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:to_state_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        RpStepUpStateTransition.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end

    assert_equal "idx_rp_step_up_state_transitions_owner_to",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    other_target = RpStepUpStateTransition.create!(
      attributes.merge(to_state_id: RpStepUpStateStatus::CANCELLED, reason_code: "user_cancelled"),
    )

    assert_equal RpStepUpStateStatus::CANCELLED, other_target.reload.to_state_id
    other_owner = owner.dup
    other_owner.public_id = "223456789abcdefghijkl"
    other_owner.state_digest = Digest::SHA256.hexdigest("another-transition-owner")
    other_owner.save!
    independent = RpStepUpStateTransition.create!(attributes.merge(owner: other_owner))

    assert_equal other_owner.id, independent.reload.owner_id
    assert_equal RpStepUpStateStatus::DISPATCHING, independent.to_state_id
  end

  test "the database rejects a reason code outside the closed contract set" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpStepUpStateTransition.insert!(
          {
            owner_id: -1,
            from_state_id: RpStepUpStateStatus::PENDING,
            to_state_id: RpStepUpStateStatus::DISPATCHING,
            reason_code: "future_reason",
            occurred_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_rp_step_up_transition_reason"
  end
end
