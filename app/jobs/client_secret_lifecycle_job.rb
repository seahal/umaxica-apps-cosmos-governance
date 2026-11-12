# frozen_string_literal: true

class ClientSecretLifecycleJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500, phase: nil, after_id: 0, through_id: nil)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500) &&
        [nil, "credentials", "receipts"].include?(phase) && after_id.is_a?(Integer) && after_id >= 0 &&
        (through_id.nil? || (through_id.is_a?(Integer) && through_id >= after_id))
      raise ArgumentError, "Secret lifecycle requires a bounded batch, supported phase and ordered integer cursors"
    end
    return if FeatureFlags.enabled?(:retention_purge_suspended)

    raise AccessOpDataUnavailableError
  end
end
