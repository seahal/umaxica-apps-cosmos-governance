# typed: false
# frozen_string_literal: true

# D-132 (2026-10-23): every Operator is ADVANCED, which requires two active Passkeys. Access owns
# ceremony execution, and Governance has no local registration path. Until the Access handoff can
# register the second credential, protected ORG actions fail explicitly when only one exists.
module OrgSecondPasskeyGate
  extend ActiveSupport::Concern

  ALLOWED_CONTROLLER_PREFIXES = %w(
    base/org/identity/passkeys base/org/verifications
  ).freeze
  MINIMUM_ACTIVE_PASSKEYS = 2

  private

  def enforce_second_passkey_gate!
    operator = current_resource
    return unless operator.is_a?(::Operator) && operator.security_mode_advanced?
    return if second_passkey_gate_allowlisted?
    return if active_operator_passkey_count(operator) >= MINIMUM_ACTIVE_PASSKEYS

    raise AccessOpDataUnavailableError
  end

  def second_passkey_gate_allowlisted?
    ALLOWED_CONTROLLER_PREFIXES.any? { |prefix| controller_path == prefix || controller_path.start_with?(prefix) }
  end

  def active_operator_passkey_count(operator)
    OperatorPasskey.where(staff_id: operator.id, status_id: OperatorPasskeyStatus::ACTIVE).count
  end
end
