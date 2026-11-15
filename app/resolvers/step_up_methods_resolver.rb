# typed: false
# frozen_string_literal: true

class StepUpMethodsResolver
  Result = Data.define(:available, :configured)

  def self.call(actor:, ticket:, supported_methods:)
    new(actor: actor, ticket: ticket, supported_methods: supported_methods).call
  end
  public_class_method :call

  def initialize(actor:, ticket:, supported_methods:)
    @actor = actor
    @ticket = ticket
    @supported_methods = supported_methods
  end

  public
  def call
    return Result.new(available: [], configured: []) if actor.blank?

    supported = Array(supported_methods)
    Result.new(
      available: StepUpAvailableMethods.call(actor, ticket: ticket) & supported,
      configured: StepUpConfiguredMethodsQuery.call(actor) & supported,
    )
  end

  private

  attr_reader :actor, :ticket, :supported_methods
end
