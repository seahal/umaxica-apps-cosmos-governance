# frozen_string_literal: true

class SeedClientRegistrationStatuses < ActiveRecord::Migration[8.2]
  class StatusRow < ActiveRecord::Base
    self.table_name = "client_registration_statuses"
  end

  public

  # 1 CREDENTIAL_PENDING, 2 COMPLETED, 3 CANCELLED, 4 EXPIRED, 5 HALTED.
  def up
    (1..5).each { |id| StatusRow.create!(id: id) }
  end

  def down
    if connection.select_value("SELECT EXISTS (SELECT 1 FROM client_registrations)")
      raise ActiveRecord::IrreversibleMigration, "Registration rows reference these statuses"
    end

    StatusRow.where(id: 1..5).delete_all
  end
end
