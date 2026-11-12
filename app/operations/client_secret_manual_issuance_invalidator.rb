# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretManualIssuanceInvalidator
  class Denied < StandardError; end

  class InvalidState < StandardError; end

  class << self
    public

    def call!(...)
      raise AccessOpDataUnavailableError
    end

    def call_for_payload_failure!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
