# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretSignInReceiptPurger
  class << self
    public

    def call!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
