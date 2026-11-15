# typed: false
# frozen_string_literal: true

# Outcome of one registration handoff. `reason` is one of the ADR's closed answer reasons, or
# :replay when the handoff's jti had already been consumed.
ClientRegistrationAnswerResult =
  Data.define(:reason, :registration, :completion) do
    def initialize(reason:, registration: nil, completion: nil)
      unless ClientRegistrationAnswerCodec::REASONS.include?(reason.to_s) || reason == :replay
        raise ArgumentError, "unsupported registration answer reason #{reason.inspect}"
      end

      super
    end

    def replay? = reason == :replay
  end
