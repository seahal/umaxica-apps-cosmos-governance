# typed: false
# frozen_string_literal: true

# These persisted transaction vocabularies remain until the deferred model/database cleanup.
module IdentitySocialCeremonyContract
  Error = Class.new(StandardError)

  SURFACES = %w(app).freeze
  OPERATIONS = %w(link login signup account_selection).freeze
  PROVIDERS = %w(apple google).freeze
end
