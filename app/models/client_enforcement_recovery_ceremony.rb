# typed: false
# frozen_string_literal: true

class ClientEnforcementRecoveryCeremony < AppPrincipalRecord
  include EnforcementRecoveryCeremonyRecordable

  belongs_to :client, inverse_of: :enforcement_recovery_ceremonies

  def self.subject_association_name = :client

  def subject = Client.find(client_id)
end
