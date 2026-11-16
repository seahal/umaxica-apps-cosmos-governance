# frozen_string_literal: true

class ValidateRetainedAppZenithConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:client_emails, name: "chk_client_emails_retention_order")
    validate_check_constraint(:client_passkeys, name: "chk_client_passkeys_retention_order")
    validate_check_constraint(:client_telephones, name: "chk_client_telephones_retention_order")
    validate_check_constraint(:clients, name: "chk_clients_terminated_requires_withdrawn")
    validate_check_constraint(:clients, name: "chk_clients_withdrawal_order")
    validate_foreign_key(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
    validate_foreign_key(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
    validate_foreign_key(:persona_memberships, name: "fk_rails_0d7f5f74b1")
    validate_foreign_key(:persona_memberships, name: "fk_rails_182816542a")
    validate_foreign_key(:client_identities, name: "fk_rails_3045b2b3f6")
    validate_foreign_key(:client_withdrawal_flows, name: "fk_rails_3a897cfb78")
    validate_foreign_key(:persona_memberships, name: "fk_rails_4f3c994599")
    validate_foreign_key(:client_profiles, name: "fk_rails_510843a98e")
    validate_foreign_key(:persona_memberships, name: "fk_rails_529c28deb1")
    validate_foreign_key(:client_withdrawal_flow_events, name: "fk_rails_7344701780")
    validate_foreign_key(:personas, name: "fk_rails_8dc042a1c9")
    validate_foreign_key(:client_withdrawal_flow_events, name: "fk_rails_9511d96f8c")
    validate_foreign_key(:client_profiles, name: "fk_rails_c49c0906dc")
    validate_foreign_key(:persona_memberships, name: "fk_rails_cdfe640663")
    validate_foreign_key(:persona_memberships, name: "fk_rails_e031c03097")
    validate_foreign_key(:client_withdrawal_flows, name: "fk_rails_e5e99fd372")
    validate_foreign_key(:client_withdrawal_flow_events, name: "fk_rails_f24d4919a7")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Keep existing constraints validated when rolling application code back"
  end
end
