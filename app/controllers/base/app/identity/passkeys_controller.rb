# frozen_string_literal: true

class Base::App::Identity::PasskeysController < Base::App::Identity::BaseController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def show
    @passkey = current_client.client_passkeys.active.find_by!(public_id: params.expect(:id))
    authorize!(@passkey, to: :show?, with: ClientPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    super
  end

  private

  def step_up_requirement(scope:, **options)
    unless scope == "settings_passkey" && options.empty?
      raise ArgumentError, "Passkey management requires its current policy"
    end

    ClientPasskeyPolicy.new(@passkey || ClientPasskey, user: current_client).management_requirement(
      token: current_session_token,
    )
  end

  def registration_surface = "app"

  def identity_actor = current_client

  def passkey_class = ClientPasskey
end
