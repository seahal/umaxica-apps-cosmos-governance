# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyReentry
  extend ActiveSupport::Concern
  include WithdrawalCeremonyAuthentication

  REENTRY_SESSION_KEY = :withdrawal_ceremony_reentry
  GENERIC_MESSAGE = I18n.t("withdrawal_ceremony_reentry.generic_message").freeze

  public

  def new
    @email_record = identity_email_model.new
    @reentry_state = withdrawal_reentry_state
    render_withdrawal_reentry_new
  end

  def create
    raise AccessOpDataUnavailableError
  end

  private

  def render_withdrawal_reentry_new(status: :ok)
    render :new, status: status
  end

  def withdrawal_reentry_state
    data = session[REENTRY_SESSION_KEY]
    return nil unless data.is_a?(Hash)

    if data["expires_at"].to_i <= Time.current.to_i
      session.delete(REENTRY_SESSION_KEY)
      return nil
    end

    data
  end

  def withdrawal_reentry_address
    params.dig(:withdrawal_reentry, :address).to_s
  end

  def withdrawal_reentry_generic_message
    GENERIC_MESSAGE
  end
end
