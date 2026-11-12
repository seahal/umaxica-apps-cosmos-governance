# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class OrgIamPrincipalCommitter
  class NestedTransactionError < StandardError; end

  class EvidenceRejected < StandardError; end

  class AuthorizationRejected < StandardError; end

  class OperationConflict < StandardError; end

  class IndeterminateCommit < StandardError; end

  class << self
    public

    def call(...)
      raise AccessOpDataUnavailableError
    end
  end
end
