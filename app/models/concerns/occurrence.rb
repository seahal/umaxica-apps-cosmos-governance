# typed: false
# frozen_string_literal: true

module Occurrence
  extend ActiveSupport::Concern

  private

  # Keep the foreign-key field in validation errors while the required
  # belongs_to association enforces that the referenced status exists.
  def status_id_must_be_present
    errors.add(:status_id, :blank) if status_id.blank?
  end
end
