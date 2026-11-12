# frozen_string_literal: true

require "test_helper"

class RpStepUpStateTest < ActiveSupport::TestCase
  test "the database rejects a state stored in the other realm" do
    result = seed_rp_cell_session(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-state-subject",
      sid: "step-up-state-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )

    state = {
      public_id: "123456789abcdefghijkl",
      rp_session_id: result.id,
      state_digest: Digest::SHA256.hexdigest("state-digest"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
      pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      pkce_verifier_ciphertext: "ciphertext:v1:test-value",
      issuer: "https://www.umaxica.app",
      realm: "ORG",
      client_id: "base-app-ww",
      return_target: "/settings/security",
      initiating_generation: 0,
      state_id: RpStepUpStateStatus::PENDING,
      expires_at: Time.utc(2099, 1, 1),
      created_at: Time.utc(2026, 11, 3, 12),
      updated_at: Time.utc(2026, 11, 3, 12),
    }

    error = assert_raises(ActiveRecord::StatementInvalid) { RpStepUpState.insert!(state) }

    assert_includes error.message, "chk_rp_step_up_states_realm"
  end

  test "the state digest is unique" do
    result = seed_rp_cell_session(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-digest-subject",
      sid: "step-up-digest-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    state = RpStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result,
      state_digest: Digest::SHA256.hexdigest("duplicate-state-digest"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
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

    duplicate = state.dup
    duplicate.public_id = "223456789abcdefghijkl"

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:state_digest, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        RpStepUpState.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end

    assert_equal "idx_rp_step_up_states_state_digest",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    distinct = state.dup
    distinct.public_id = "323456789abcdefghijkl"
    distinct.state_digest = Digest::SHA256.hexdigest("distinct-state-digest")
    distinct.save!
    public_duplicate = state.dup
    public_duplicate.state_digest = Digest::SHA256.hexdigest("distinct-public-id-candidate")

    assert_not public_duplicate.valid?
    assert public_duplicate.errors.of_kind?(:public_id, :taken)
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        RpStepUpState.transaction(requires_new: true) { public_duplicate.save!(validate: false) }
      end

    assert_equal "idx_rp_step_up_states_public_id",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    assert_predicate state.reload, :valid?
  end
end
