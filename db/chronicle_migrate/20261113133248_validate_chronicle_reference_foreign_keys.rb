# frozen_string_literal: true

class ValidateChronicleReferenceForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:app_document_audits, "fk_rails_04199ae3cc"],
    [:org_timeline_audits, "fk_rails_1c8eb96fbb"],
    [:app_timeline_audits, "fk_rails_2babaf0d7d"],
    [:org_preference_chronicles, "fk_rails_3829eb3d72"],
    [:operator_chronicles, "fk_rails_46a8075569"],
    [:org_document_audits, "fk_rails_46d3b866ce"],
    [:com_preference_chronicles, "fk_rails_592279f49b"],
    [:chronicle_outbox_entries, "fk_rails_6a19517853"],
    [:client_chronicles, "fk_rails_829f1830de"],
    [:client_chronicles, "fk_rails_868bedb021"],
    [:app_document_audits, "fk_rails_a9e9b70220"],
    [:app_timeline_audits, "fk_rails_b95cff528f"],
    [:com_preference_chronicles, "fk_rails_c194bd8de2"],
    [:app_preference_chronicles, "fk_rails_d693b46c45"],
    [:app_preference_chronicles, "fk_rails_da47dd8941"],
    [:org_timeline_audits, "fk_rails_eae8a241e3"],
    [:org_document_audits, "fk_rails_ed52fec6a9"],
    [:operator_chronicles, "fk_rails_f0451c267b"],
    [:org_preference_chronicles, "fk_rails_f932dbadd7"],
  ].freeze

  def change
    FOREIGN_KEYS.each { |table, name| validate_foreign_key(table, name: name) }
  end

  def down
    # PostgreSQL cannot unvalidate a foreign key without dropping it; keep the stronger constraint.
  end
end
