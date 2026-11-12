# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class OrgIamAuditedCommitter
  class InvalidRequest < StandardError; end

  class OperationConflict < StandardError; end

  class OutcomeUnavailable < StandardError; end

  class << self
    public

    def call(...)
      raise AccessOpDataUnavailableError
    end
  end
end
