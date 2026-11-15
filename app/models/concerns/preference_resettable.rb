# typed: false
# frozen_string_literal: true

module PreferenceResettable
  extend ActiveSupport::Concern

  public
  def require_reset_confirmation(value)
    self.confirm_reset = value
    self
  end

  private

  def confirm_reset_accepted
    return if confirm_reset == "1"

    errors.add(:confirm_reset, :accepted)
  end
end
