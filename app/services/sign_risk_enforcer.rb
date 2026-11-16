# typed: false
# frozen_string_literal: true

class SignRiskEnforcer
  # resource: The user/staff record (ActiveRecord)
  def self.call(resource)
    return unless feature_enabled?
    return unless resource

    score =
      case resource
      when Operator then SignRiskEngine.score(staff_id: resource.id)
      when Client then SignRiskEngine.score(user_id: resource.id)
      else raise ArgumentError, "unsupported risk subject"
      end

    if score >= 100
      revoke!(resource)
    elsif score >= 60
      require_step_up!(resource)
    end
  end
  public_class_method :call

  # D-172 S-1: a risk stop ends every root of the principal with an epoch cutoff, through the
  # identity-stop path (Zenith event under the actor lock, then the OP apply with its retry).
  def self.revoke!(resource)
    delivery_result = nil
    resource.class.transaction do
      IdentityAuthenticationStopRecorder.call(actor: resource.class.lock.find(resource.id), reason: "sign_risk")
      resource.class.current_transaction.after_commit do
        raise AccessOpDataUnavailableError
      end
    end
    delivery_result
  end
  public_class_method :revoke!

  def self.require_step_up!(_resource)
    raise AccessOpDataUnavailableError
  end
  public_class_method :require_step_up!

  def self.feature_enabled?
    return false if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"

    enabled_config = Rails.configuration.try(:x).try(:risk_enforcement).try(:enabled)
    enabled_config || ENV["RISK_ENFORCEMENT_ENABLED"] == "true" || Rails.env.production?
  end
  public_class_method :feature_enabled?
end
