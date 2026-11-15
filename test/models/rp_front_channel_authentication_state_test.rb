# frozen_string_literal: true

require "test_helper"

class RpFrontChannelAuthenticationStateTest < ActiveSupport::TestCase
  CONSUMED_JTI_MODELS = [RpBaseAppConsumedIdTokenJti, RpBaseOrgConsumedIdTokenJti].freeze
  EVIDENCE_CELLS = [
    [RpBaseAppSessionAuthenticationEvidence, "rp_base_app", "https://visa.umaxica.app"],
    [RpBaseOrgSessionAuthenticationEvidence, "rp_base_org", "https://visa.umaxica.org"],
  ].freeze

  test "both Base consumed jti models validate digest uniqueness" do
    CONSUMED_JTI_MODELS.each do |model|
      attributes = { jti_digest: "a" * 64, expires_at: 1.minute.from_now }
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?, model.name
      assert duplicate.errors.of_kind?(:jti_digest, :taken)
    end
  end

  test "both Base authentication evidence models validate per-session uniqueness and column lengths" do
    EVIDENCE_CELLS.each do |model, connection, issuer|
      cell = RpCellBinding.fetch(connection)
      session = seed_rp_cell_session(
        cell:, issuer:, subject: "authentication-evidence-subject", sid: "authentication-evidence-sid",
        absolute_expires_at: 1.hour.from_now,
      )
      existing = model.find_by!(rp_session_id: session.id)
      duplicate = model.new(existing.attributes.except("id", "created_at", "updated_at"))

      assert_not duplicate.valid?, model.name
      assert duplicate.errors.of_kind?(:rp_session_id, :taken)

      invalid_digest = model.new(existing.attributes.except("id", "created_at", "updated_at"))
      invalid_digest.id_token_jti_digest = "a" * 63

      assert_not invalid_digest.valid?, model.name
      assert_includes invalid_digest.errors.details.fetch(:id_token_jti_digest), error: :wrong_length, count: 64

      invalid_context = model.new(existing.attributes.except("id", "created_at", "updated_at"))
      invalid_context.authentication_context = "x" * 17

      assert_not invalid_context.valid?, model.name
      assert_includes invalid_context.errors.details.fetch(:authentication_context), error: :too_long, count: 16
    end
  end
end
