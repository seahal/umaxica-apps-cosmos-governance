# frozen_string_literal: true

# The Governance feature requires Access-owned proof or retention state; its API is not available.
class RetentionCrossDatabaseChildPurge
  class << self
    public

    def call(actor:)
      raise ArgumentError, "unsupported retention actor" unless actor.is_a?(Client) || actor.is_a?(Operator)

      raise AccessOpDataUnavailableError
    end
  end
end
