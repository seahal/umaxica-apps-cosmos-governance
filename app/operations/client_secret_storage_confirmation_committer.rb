# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class ClientSecretStorageConfirmationCommitter
  class TransactionConflict < ArgumentError; end

  class Denied < StandardError; end

  class InvalidState < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(...)
      raise AccessOpDataUnavailableError
    end
  end
end
