# frozen_string_literal: true

require "test_helper"

class OrgIamOperationOutcomeUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an operation reserves its receipt globally across actors and operation kinds" do
    attributes = {
      operation_id: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a31",
      operation_kind: "grant",
      actor_public_id: "actor-ref",
      subject_public_id: "subject-ref",
      request_digest: "a" * 64,
      result: { grant_public_id: "grant-ref", expires_at: "2026-11-13T00:00:00Z" },
    }
    original = OrgIamOperationOutcome.create!(attributes)
    duplicate = OrgIamOperationOutcome.new(
      attributes.merge(
        actor_public_id: "other-actor", operation_kind: "revoke",
        result: { grant_public_id: "grant-ref" },
      ),
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:operation_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate original, :valid?

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        OrgZenithRecord.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    assert_equal "index_org_iam_operation_outcomes_on_operation_id",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    distinct = OrgIamOperationOutcome.create!(attributes.merge(operation_id: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a32"))

    assert_predicate distinct, :persisted?
  end
end
