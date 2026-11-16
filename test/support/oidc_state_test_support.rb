# frozen_string_literal: true

# Reads claims from an RP state token in tests without verifying the token twice.
module OidcStateTestSupport
  module_function

  def claims(state)
    JWT.decode(state.to_s, nil, false).first
  end

  def jti(state) = claims(state).fetch("jti")

  def target_link_uri(state) = claims(state)["target_link_uri"]
end
