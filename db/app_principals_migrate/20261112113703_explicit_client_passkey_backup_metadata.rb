# frozen_string_literal: true

# Converts observations without inventing a negative value for legacy unknown metadata.
# This rewrites the table under an exclusive lock; production execution needs its own plan.
class ExplicitClientPasskeyBackupMetadata < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_column(:client_passkeys, :backup_eligible, :backup_eligibility)
      rename_column(:client_passkeys, :backup_state, :backup_observation)
      change_column(
        :client_passkeys, :backup_eligibility, :string,
        using: "CASE backup_eligibility WHEN TRUE THEN 'eligible' WHEN FALSE THEN 'ineligible' ELSE 'unknown' END",
      )
      change_column(
        :client_passkeys, :backup_observation, :string,
        using: "CASE backup_observation WHEN TRUE THEN 'backed_up' WHEN FALSE THEN 'not_backed_up' ELSE 'unknown' END",
      )
      change_column_null(:client_passkeys, :backup_eligibility, false)
      change_column_null(:client_passkeys, :backup_observation, false)
    end

    change_column_default(:client_passkeys, :backup_eligibility, "unknown")
    change_column_default(:client_passkeys, :backup_observation, "unknown")
    add_check_constraint(
      :client_passkeys, "backup_eligibility IN ('unknown', 'ineligible', 'eligible')",
      name: "chk_client_passkeys_backup_eligibility", validate: false,
    )
    add_check_constraint(
      :client_passkeys, "backup_observation IN ('unknown', 'not_backed_up', 'backed_up')",
      name: "chk_client_passkeys_backup_observation", validate: false,
    )
    # The reviewed atomic rewrite already holds the exclusive lock. Validate both checks now
    # rather than commit an intermediate unvalidated schema or split the information conversion.
    safety_assured do
      validate_check_constraint(:client_passkeys, name: "chk_client_passkeys_backup_eligibility")
      validate_check_constraint(:client_passkeys, name: "chk_client_passkeys_backup_observation")
    end
  end

  def down
    remove_check_constraint(:client_passkeys, name: "chk_client_passkeys_backup_eligibility")
    remove_check_constraint(:client_passkeys, name: "chk_client_passkeys_backup_observation")
    change_column_default(:client_passkeys, :backup_eligibility, nil)
    change_column_default(:client_passkeys, :backup_observation, nil)
    change_column_null(:client_passkeys, :backup_eligibility, true)
    change_column_null(:client_passkeys, :backup_observation, true)
    safety_assured do
      change_column(
        :client_passkeys, :backup_eligibility, :boolean,
        using: "CASE backup_eligibility WHEN 'eligible' THEN TRUE WHEN 'ineligible' THEN FALSE ELSE NULL END",
      )
      change_column(
        :client_passkeys, :backup_observation, :boolean,
        using: "CASE backup_observation WHEN 'backed_up' THEN TRUE WHEN 'not_backed_up' THEN FALSE ELSE NULL END",
      )
      rename_column(:client_passkeys, :backup_eligibility, :backup_eligible)
      rename_column(:client_passkeys, :backup_observation, :backup_state)
    end
  end
end
