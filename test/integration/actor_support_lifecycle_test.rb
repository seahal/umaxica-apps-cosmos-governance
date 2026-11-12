# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module ActorSupportLifecycle
  private

  def actor_support_snapshot
    preference = Actor.preferences
    cookie = preference.cookie
    actor = Actor.actor
    context = current_actor
    resource = current_resource if respond_to?(:current_resource, true)

    {
      current_actor_class: context.class.name,
      current_actor_actor_class: context.actor.class.name,
      current_actor_actor_id: context.actor.respond_to?(:id) ? context.actor.id : nil,
      current_actor_authn_null: context.authn.null?,
      current_actor_step_up_class: context.step_up.class.name,
      current_resource_class: resource&.class&.name,
      current_resource_id: resource&.id,
      actor_class: actor.class.name,
      actor_id: actor.respond_to?(:id) ? actor.id : nil,
      actor_type: Actor.actor_type.to_s,
      whoami: Actor.whoami.to_s,
      signed_in: Actor.signed_in?,
      signed_up: Actor.signed_up?,
      tld: Actor.tld.to_s,
      authentication: actor_support_authentication_snapshot,
      preference: actor_support_preference_snapshot(preference, cookie),
    }
  end

  def actor_support_authentication_snapshot
    {
      null: Actor.authn.null?,
      login_public_id: Actor.authn.login_public_id,
      acr: Actor.authn.acr,
      amr: Actor.authn.amr,
      access_claim_sid: Actor.authn.access_claims&.dig("sid"),
      access_claim_prf: Actor.authn.access_claims&.dig("prf"),
    }
  end

  def actor_support_preference_snapshot(preference, cookie)
    {
      null: preference.null?,
      language: preference.language,
      region: preference.region,
      timezone: preference.timezone,
      theme: preference.theme,
      currency: preference.currency,
      date_format: preference.date_format,
      time_format: preference.time_format,
      motion: preference.motion,
      density: preference.density,
      page_size: preference.page_size,
      cookie: {
        consented: cookie.consented?,
        functional: cookie.functional?,
        performant: cookie.performant?,
        targetable: cookie.targetable?,
        consent_version: cookie.consent_version,
        consented_at: cookie.consented_at&.to_s,
      },
    }
  end

  def actor_policy_snapshot
    {
      allowed: current_resource.present?,
      authorization_actor_class: authorization_context[:actor].class.name,
      authorization_actor_actor_class: authorization_context[:actor].actor.class.name,
      authorization_user_class: authorization_context[:user]&.class&.name,
    }
  end
end

class ActorSupportLifecyclePolicy < ApplicationPolicy
  def show?
    actor.is_a?(Actor::Context) && record.present? && user == record
  end
end

module Base
  module App
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      AUTHENTICATION_MODE = :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        authorize!(current_resource, to: :show?, with: ActorSupportLifecyclePolicy) if current_resource.present?

        render json: actor_policy_snapshot
      end
    end
  end

  module Org
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      AUTHENTICATION_MODE = :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        render json: actor_policy_snapshot
      end
    end
  end

  module Com
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      AUTHENTICATION_MODE = :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        render json: actor_policy_snapshot
      end
    end
  end
end

class ActorSupportLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Actor.reset
    Rails.application.routes.draw do
      get "/actor-support/acme-app", to: "base/app/actor_support#show"
      get "/actor-support/acme-app-policy", to: "base/app/actor_support#policy"
      get "/actor-support/acme-org", to: "base/org/actor_support#show"
      get "/actor-support/acme-org-policy", to: "base/org/actor_support#policy"
    end
  end

  teardown do
    Rails.application.reload_routes!
    Actor.reset
  end

  test "Base APP request does not use user preference record as runtime fallback and resets afterwards" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
      created_at: Time.current,
      updated_at: Time.current,
    )
    resource_preference = ClientPreference.create!(client: user)
    ClientPreferenceCurrencyOption.ensure_defaults!
    ClientPreferenceLanguage.create!(
      preference: resource_preference, option_id: ClientPreferenceLanguageOption::EN,
    )
    ClientPreferenceCurrency.create!(
      preference: resource_preference, option_id: ClientPreferenceCurrencyOption::USD,
    )

    host!(host)
    http_headers_5 = as_user_headers(user, host: host)
    get "/actor-support/acme-app", params: { ri: "jp" }, headers: http_headers_5

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Client", snapshot["actor_class"]
    assert_equal user.id, snapshot["actor_id"]
    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal "Client", snapshot["current_actor_actor_class"]
    assert_equal user.id, snapshot["current_actor_actor_id"]
    assert_equal "Actor::StepUp", snapshot["current_actor_step_up_class"]
    assert_equal "Client", snapshot["current_resource_class"]
    assert_equal user.id, snapshot["current_resource_id"]
    assert_equal "client", snapshot["actor_type"]
    assert_equal "client", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "app", snapshot["tld"]
    assert_equal({ "client" => "app" }, { snapshot["whoami"] => snapshot["tld"] })
    # Hydrated from the session preference payload (default-seeded), so it is no
    # longer null. The resource ClientPreference (language "en", currency "usd")
    # must still NOT be used as a runtime fallback: language stays the session
    # default "ja" and currency "jpy".
    assert_not snapshot["preference"]["null"]
    assert_equal "ja", snapshot["preference"]["language"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "infinity", snapshot["preference"]["page_size"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.tld
  end

  test "Base ORG request does not use staff preference record as runtime fallback and resets afterwards" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorPasskeyTestSupport.give_two_active_passkeys!(staff)
    resource_preference = OperatorPreference.create!(operator: staff)
    OperatorPreferenceCurrencyOption.ensure_defaults!
    OperatorPreferenceLanguage.create!(
      preference: resource_preference, option_id: OperatorPreferenceLanguageOption::EN,
    )
    OperatorPreferenceCurrency.create!(
      preference: resource_preference, option_id: OperatorPreferenceCurrencyOption::USD,
    )

    host!(host)
    http_headers_4 = as_staff_headers(staff, host: host)
    get "/actor-support/acme-org", params: { ri: "jp" }, headers: http_headers_4

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Operator", snapshot["actor_class"]
    assert_equal staff.id, snapshot["actor_id"]
    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal "Operator", snapshot["current_actor_actor_class"]
    assert_equal staff.id, snapshot["current_actor_actor_id"]
    assert_equal "Operator", snapshot["current_resource_class"]
    assert_equal staff.id, snapshot["current_resource_id"]
    assert_equal "operator", snapshot["actor_type"]
    assert_equal "operator", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "org", snapshot["tld"]
    assert_equal({ "operator" => "org" }, { snapshot["whoami"] => snapshot["tld"] })
    # Hydrated from the session preference payload (default-seeded), so it is no
    # longer null. The resource OperatorPreference (language "en", currency "usd")
    # must still NOT be used as a runtime fallback.
    assert_not snapshot["preference"]["null"]
    assert_equal "ja", snapshot["preference"]["language"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "infinity", snapshot["preference"]["page_size"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.tld
  end

  test "unauthenticated request exposes unauthenticated current_actor context" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    host!(host)
    get "/actor-support/acme-app", params: { ri: "jp" }

    assert_response :success
    snapshot = response.parsed_body

    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal Unauthenticated.instance.class.name, snapshot["current_actor_actor_class"]
    assert snapshot["current_actor_authn_null"]
    assert_nil snapshot["current_resource_class"]
    assert_equal "unauthenticated", snapshot["actor_type"]
    assert_not snapshot["signed_in"]
  end

  test "action policy receives current_actor context for authenticated app request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
      created_at: Time.current,
      updated_at: Time.current,
    )

    host!(host)
    http_headers_2 = as_user_headers(user, host: host)
    get "/actor-support/acme-app-policy", params: { ri: "jp" }, headers: http_headers_2

    assert_response :success
    snapshot = response.parsed_body

    assert snapshot["allowed"]
    assert_equal "ActorValuesContext", snapshot["authorization_actor_class"]
    assert_equal "Client", snapshot["authorization_actor_actor_class"]
    assert_equal "Client", snapshot["authorization_user_class"]
  end

  test "sequential app and org requests rebuild actor context without cross surface leakage" do
    app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
      created_at: Time.current,
      updated_at: Time.current,
    )
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorPasskeyTestSupport.give_two_active_passkeys!(staff)

    host!(app_host)
    http_headers_1 = as_user_headers(user, host: app_host)
    get "/actor-support/acme-app", params: { ri: "jp" }, headers: http_headers_1

    assert_response :success
    app_snapshot = response.parsed_body

    assert_equal "Client", app_snapshot["actor_class"]
    assert_equal user.id, app_snapshot["actor_id"]
    assert_equal "client", app_snapshot["actor_type"]
    assert_equal "app", app_snapshot["tld"]
    assert_equal Unauthenticated.instance, Actor.actor
    assert_nil Actor.tld

    host!(org_host)
    http_headers_0 = as_staff_headers(staff, host: org_host)
    get "/actor-support/acme-org", params: { ri: "jp" }, headers: http_headers_0

    assert_response :success
    org_snapshot = response.parsed_body

    assert_equal "Operator", org_snapshot["actor_class"]
    assert_equal staff.id, org_snapshot["actor_id"]
    assert_equal "operator", org_snapshot["actor_type"]
    assert_equal "org", org_snapshot["tld"]
    assert_not_equal app_snapshot["actor_type"], org_snapshot["actor_type"]
    assert_not_equal app_snapshot["tld"], org_snapshot["tld"]
    assert_equal Unauthenticated.instance, Actor.actor
    assert_nil Actor.tld
  end

  test "action policy fails closed for unauthenticated app request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    host!(host)
    get "/actor-support/acme-app-policy", params: { ri: "jp" }

    assert_response :success

    snapshot = response.parsed_body

    assert_not snapshot["allowed"]
    assert_equal "ActorValuesContext", snapshot["authorization_actor_class"]
    assert_equal Unauthenticated.instance.class.name, snapshot["authorization_actor_actor_class"]
    assert_nil snapshot["authorization_user_class"]
  end
end
