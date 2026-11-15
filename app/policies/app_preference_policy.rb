# typed: false
# frozen_string_literal: true

class AppPreferencePolicy < ApplicationPolicy
  public
  def update?
    record == AppPreference || record.is_a?(AppPreference)
  end
end
