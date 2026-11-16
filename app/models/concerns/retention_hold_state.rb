# typed: false
# frozen_string_literal: true

module RetentionHoldState
  extend ActiveSupport::Concern

  HOLD_KINDS = %w(legal_hold).freeze
  REASON_CODES = %w(legal_hold security_investigation billing_dispute abuse_investigation court_order other).freeze

  class_methods do
    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end
  end

  public
  def active_at?(now = Time.current)
    status_id == self.class.status_id_for("ACTIVE") && (expires_at.blank? || expires_at > now)
  end

  private

  def assign_retention_hold_defaults
    self.class::STATUS_MODEL.ensure_defaults!
    self.hold_kind = "legal_hold" if hold_kind.blank?
    self.reason_code = "legal_hold" if reason_code.blank?
    self.status_id ||= self.class.status_id_for("ACTIVE")
    self.applied_at ||= Time.current
  end
end
