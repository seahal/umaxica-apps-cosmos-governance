# typed: false
# frozen_string_literal: true

module AccountAssignment
  extend ActiveSupport::Concern

  public
  def active?
    revoked_at.blank?
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(at: Time.current)
    update!(revoked_at: at)
  end

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
