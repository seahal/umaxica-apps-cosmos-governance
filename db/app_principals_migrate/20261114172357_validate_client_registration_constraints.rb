# frozen_string_literal: true

class ValidateClientRegistrationConstraints < ActiveRecord::Migration[8.2]
  public

  def change
    validate_check_constraint(:client_registration_statuses, name: "chk_client_registration_statuses_id")
    validate_foreign_key(:client_registrations, :client_registration_statuses)
    validate_foreign_key(:client_registrations, :client_registration_completion_methods)
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_public_id")
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_user_handle")
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_ceremony_digest")
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_browser_digest")
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_identifier_digest")
    validate_check_constraint(:client_registrations, name: "chk_client_registrations_finite_times")
    validate_check_constraint(
      :client_registration_handoff_receipts, name: "chk_client_registration_handoff_receipts_kind",
    )
    validate_check_constraint(
      :client_registration_handoff_receipts, name: "chk_client_registration_handoff_receipts_jti_digest",
    )
    validate_check_constraint(
      :client_registration_audit_outboxes, name: "chk_client_registration_audit_outboxes_event_type",
    )
  end
end
