# frozen_string_literal: true

class Base::Org::Identity::PasskeysController < Base::Org::ApplicationController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def show
    @passkey = current_operator.staff_passkeys.active.find_by!(external_id: params.expect(:id))
    authorize!(@passkey, to: :show?, with: OperatorPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    super
  end

  private

  def step_up_requirement(scope:, **options)
    unless scope == "settings_passkey" && options.empty?
      raise ArgumentError, "Passkey management requires its current policy"
    end

    OperatorPasskeyPolicy.new(
      @passkey || OperatorPasskey,
      user: current_operator,
    ).management_requirement(token: current_session_token)
  end

  def registration_surface = "org"

  def identity_actor = current_operator

  def passkey_class = OperatorPasskey

  def passkey_reference_attribute = :external_id
end
