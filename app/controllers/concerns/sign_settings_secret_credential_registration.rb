# typed: false
# frozen_string_literal: true

module SignSettingsSecretCredentialRegistration
  extend ActiveSupport::Concern

  private

  def create_settings_secret_credential!(actor:, name:, enabled:, raw_secret_credential:)
    step_up_bootstrap = step_up_bootstrap_unconfigured?(actor)
    OperatorSecretCredentialsCreate.call(
      actor: actor,
      staff: actor,
      params: { name: name, enabled: enabled },
      raw_secret_credential: raw_secret_credential,
      step_up_token: current_session_token,
      step_up_evidence: step_up_bootstrap ? nil : current_step_up_evidence,
      step_up_bootstrap: step_up_bootstrap,
    )
  end
end
