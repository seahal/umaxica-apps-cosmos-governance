# typed: false
# frozen_string_literal: true

# RP-side Tech gate (R5-WU11): the org authority's decision is asked over HTTPS on every check
# through TechCapabilityClient. The record carries only the authenticated Tech RP session.
class TechRemoteAccessPolicy < ApplicationPolicy
  Request = Data.define(:rp_session)

  public

  def show?
    record.is_a?(Request) && TechCapabilityClient.allowed?(rp_session: record.rp_session)
  end
end
