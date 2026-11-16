# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretIssuancePurger
  class << self
    public

    def call_omitted!(...)
      raise AccessOpDataUnavailableError
    end

    def call_confirmed!(...)
      raise AccessOpDataUnavailableError
    end

    def call!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
