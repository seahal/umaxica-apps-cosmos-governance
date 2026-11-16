# frozen_string_literal: true

# Read-only passkey inventory for the Base account screens.
module BaseIdentityPasskeyManagement
  extend ActiveSupport::Concern

  public

  def index
    authorize!(passkey_class, to: :index?)
    @passkeys = passkey_relation.order(created_at: :asc)
    render inertia: passkey_index_component, props: {
      title: t("base.shared.identity.passkeys.title"),
      description: t("base.shared.identity.passkeys.description"),
      back_link: { label: t("base.shared.identity.up_link"), href: identity_path },
      empty_message: t("views.sign.app.settings.passkeys.index.empty"),
      passkeys: @passkeys.map { |passkey| serialize_passkey(passkey) },
    }
  end

  def show
    @passkey = passkey_relation.find_by!(passkey_reference_attribute => params.expect(:id))
    authorize!(@passkey)
    render inertia: passkey_show_component, props: passkey_show_props
  end

  private

  def passkey_relation
    case identity_actor
    when Client then identity_actor.client_passkeys.active
    when Operator then identity_actor.staff_passkeys.active
    else raise ArgumentError, "unsupported passkey owner"
    end
  end

  def serialize_passkey(passkey)
    {
      public_id: passkey_reference(passkey),
      description: passkey.description,
      created_at: passkey.created_at&.iso8601,
      last_used_at: passkey.last_used_at&.iso8601,
      show_href: passkey_path(passkey_reference(passkey)),
    }
  end

  def passkey_index_component = "base/#{registration_surface}/identity/passkeys/index"

  def passkey_show_component = "base/#{registration_surface}/identity/passkeys/show"

  def passkey_show_props(error: nil)
    {
      title: t("base.shared.identity.passkeys.title"),
      description: @passkey.description,
      back_link: { label: t("actions.back"), href: passkeys_path },
      passkey: {
        description: @passkey.description,
        description_label: t("activerecord.attributes.user_passkey.description"),
        created_at: @passkey.created_at&.iso8601,
        last_used_at: @passkey.last_used_at&.iso8601,
      },
    }
  end

  def identity_path
    case registration_surface
    when "app" then base_app_identity_path(ri: params[:ri])
    when "org" then base_org_identity_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkeys_path
    case registration_surface
    when "app" then base_app_identity_passkeys_path(ri: params[:ri])
    when "org" then base_org_identity_passkeys_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_path(public_id)
    case registration_surface
    when "app" then base_app_identity_passkey_path(public_id, ri: params[:ri])
    when "org" then base_org_identity_passkey_path(public_id, ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_reference_attribute = :public_id

  def passkey_reference(passkey)
    case passkey
    when OperatorPasskey then passkey.external_id
    when ClientPasskey then passkey.public_id
    else raise ArgumentError, "unsupported passkey credential"
    end
  end

  def registration_surface
    raise NotImplementedError, "#{self.class} must define #registration_surface"
  end

  def identity_actor
    raise NotImplementedError, "#{self.class} must define #identity_actor"
  end

  def passkey_class
    raise NotImplementedError, "#{self.class} must define #passkey_class"
  end
end
