# typed: false
# frozen_string_literal: true

class FlowError < StandardError; end

class FlowConfigurationError < FlowError; end

class FlowInvalidTransition < FlowError; end

module FlowBase
  extend ActiveSupport::Concern

  class_methods do
    public

    def cycle_status_column_name
      nil
    end

    def cycle_status_column(column_name)
      return if cycle_status_column_name == column_name.to_sym

      raise FlowConfigurationError,
            "#{name} must declare cycle_status_column_name as #{column_name.to_sym.inspect}"
    end
  end

  public

  def cycle_status_id
    self[configured_cycle_status_column]
  end

  def cycle_status?(status_id)
    cycle_status_id == status_id
  end

  # The cycle_* predicates delegate to Retainable. Host classes are expected
  # to `include Retainable` (WithdrawalFlow does so for account withdrawal).
  # Kept as named aliases so callers can use intent-revealing names within
  # the cycle namespace; new code may use `accessible?` / `purgeable?` /
  # `expired_or_lapsed?` directly.
  def cycle_accessible?(now = Time.current)
    retainable_required!(:accessible?)
    accessible?(now)
  end

  def with_cycle_lock
    raise ArgumentError, "block required" unless block_given?
    raise FlowInvalidTransition, "cycle must be persisted" unless persisted?

    return yield if @_in_cycle_lock

    self.class.connection_class_for_self.connected_to(role: :writing) do
      self.class.transaction(requires_new: true) do
        lock!
        @_in_cycle_lock = true
        begin
          yield
        ensure
          @_in_cycle_lock = false
        end
      end
    end
  end

  private

  def configured_cycle_status_column
    column = self.class.cycle_status_column_name
    raise FlowConfigurationError, "#{self.class.name} must configure cycle_status_column" if column.blank?

    ensure_cycle_column!(column)
    column
  end

  # Keep transition validation private to the shared base so withdrawal
  # operations cannot bypass their declared source states.
  def ensure_cycle_transition_allowed!(next_status_id, allowed_from:, now:)
    unless Array(allowed_from).include?(cycle_status_id)
      raise FlowInvalidTransition, "invalid transition from #{cycle_status_id.inspect} to #{next_status_id.inspect}"
    end

    raise FlowInvalidTransition, "cycle is discarded" unless cycle_accessible?(now)
    raise FlowInvalidTransition, "cycle is expired" if cycle_expires_at_lapsed?(now)
  end

  def ensure_cycle_column!(column)
    return if has_attribute?(column)

    raise FlowConfigurationError, "#{self.class.name} does not have #{column}"
  end

  def retainable_required!(method_name)
    return if respond_to?(method_name)

    raise FlowConfigurationError,
          "#{self.class.name} must `include Retainable` to use cycle_#{method_name.to_s.delete_suffix("?")}?"
  end

  def cycle_expires_at_lapsed?(now)
    return false unless has_attribute?(:expires_at)

    cycle_past_or_present_time?(expires_at, now)
  end

  def cycle_past_or_present_time?(value, now)
    return false if value.blank? || cycle_infinite_time?(value)

    value <= now
  end

  def cycle_infinite_time?(value)
    value.respond_to?(:infinite?) && value.infinite?
  end
end
