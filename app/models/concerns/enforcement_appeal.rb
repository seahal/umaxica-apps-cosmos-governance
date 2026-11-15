# typed: false
# frozen_string_literal: true

module EnforcementAppeal
  extend ActiveSupport::Concern

  STATES = %w(submitted under_review approved rejected redacted).freeze
  REASON_CODES = %w(incorrect_decision new_information other).freeze
  RESOLUTION_CODES = %w(approved rejected).freeze
  MAXIMUM_STATEMENT_LENGTH = 4_000

  class ReviewerSeparationError < StandardError; end

  class InvalidResolutionError < StandardError; end

  public

  def redact!
    update!(statement: nil, state: "redacted", redacted_at: Time.current)
  end

  def submit!
    save!
    # Submitted by the principal, not an operator.
    enforcement_case.write_audit_event_once!("appeal_submitted", actor_operator_public_id: nil)
  end

  def resolve!(reviewer_operator_public_id:, resolution_code:, step_up_token: nil, step_up_actor: nil,
               step_up_evidence: nil)
    raise AccessOpDataUnavailableError
  end

  def redacted? = state == "redacted"

  private

  def reviewer_is_separate_from_case_operators
    return if reviewer_operator_public_id.blank?
    return if reviewer_operator_public_id != enforcement_case.applied_by_operator_public_id &&
      reviewer_operator_public_id != enforcement_case.approved_by_operator_public_id

    errors.add(:reviewer_operator_public_id, "must differ from the applying and approving operators")
  end
end
