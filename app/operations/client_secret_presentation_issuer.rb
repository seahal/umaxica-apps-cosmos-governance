# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretPresentationIssuer
  class Denied < StandardError; end

  class AlreadyPresented < Denied; end

  class PayloadUnavailable < Denied; end

  class << self
    public

    def prepare!(...)
      raise AccessOpDataUnavailableError
    end

    def call!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
