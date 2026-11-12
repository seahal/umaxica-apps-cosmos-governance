# frozen_string_literal: true

# Authority mutations require an Access proof; a local RP session cannot replace that authority.
class StepUpEvidenceVerifier
  STEP_UP_ACR = StepUpEvidenceResolver::STEP_UP_ACR

  class << self
    public

    def call(evidence:, actor:, token:)
      new(evidence:, actor:, token:).call
    end
  end

  def initialize(evidence:, actor:, token:)
    @evidence = evidence
    @actor = actor
    @token = token
  end

  public

  def call
    raise AccessOpDataUnavailableError
  end
end
