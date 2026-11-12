# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretNameCommitter
  class TransactionConflict < ArgumentError; end

  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class InvalidName < ArgumentError; end

  class << self
    public

    def call!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
