# frozen_string_literal: true

# Governance session management requires the Access-owned session authority.
class AccountSessionRevocation < ApplicationService
  class << self
    public

    def emergency_revoke!(...)
      raise AccessOpDataUnavailableError
    end

    def purge!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
