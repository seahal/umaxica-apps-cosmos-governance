# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWriteBoundaryTest < ActiveSupport::TestCase
  REALM_MODELS = {
    com: ComPreference,
    app: AppPreference,
    org: OrgPreference,
  }.freeze

  test "accepts the closed operation set on the owning surface" do
    {
      "base/com" => :com, "base/app" => :app, "base/org" => :org,
    }.each do |surface_key, realm|
      result = PreferenceWriteBoundary.authorize!(
        surface_key: surface_key, operation: :save, realm_model: REALM_MODELS.fetch(realm),
      )

      assert_equal realm, result[:realm]
      assert_equal :save, result[:operation]
    end
  end

  test "does not authorize preference writers outside owned surfaces" do
    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize!(
        surface_key: "other/app", operation: :save, realm_model: AppPreference,
      )
    end

    %i(sign_in sign_out).each do |operation|
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/app", operation:, realm_model: AppPreference,
        )
      end
    end
  end

  test "refuses an operation outside the closed enumeration" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :purge, realm_model: ComPreference,
        )
      end

    assert_match(/unsupported preference operation/, error.message)
  end

  test "refuses a removed sign-in operation" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/app", operation: :sign_in, realm_model: AppPreference,
        )
      end

    assert_match(/unsupported preference operation/, error.message)
  end

  test "refuses an unlisted surface entirely" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "other/org", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_equal "other/org", error.message
  end

  test "refuses a surface that names another realm's model class" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_match(/may not write/, error.message)
  end

  test "refuses a lookalike model name and a missing model" do
    ["Other::ComPreference", "ComPreferencePreference", "", nil].each do |model|
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(surface_key: "base/com", operation: :save, realm_model: model)
      end
    end
  end

  test "static Base writer authorization covers only declared realm update and reset callers" do
    {
      "base/com" => [
        Base::Com::Api::V0::Preferences::CookiesController,
        Base::Com::Api::V0::Preferences::ThemesController,
        Base::Com::Api::V0::Preferences::WebPushesController,
        Base::Com::Preference::CookiesController,
        Base::Com::Preference::ThemesController,
        Base::Com::Preference::CurrenciesController,
        Base::Com::Preference::CalendarsController,
        Base::Com::Preference::ClocksController,
        Base::Com::Preference::MotionsController,
        Base::Com::Preference::DensitiesController,
        Base::Com::Preference::PaginationsController,
        Base::Com::Preference::LanguagesController,
        Base::Com::Preference::TimezonesController,
        Base::Com::Preference::RegionsController,
        Base::Com::Preference::ScreensController,
      ],
      "base/app" => [
        Base::App::Api::V0::Preferences::CookiesController,
        Base::App::Api::V0::Preferences::ThemesController,
        Base::App::Preference::CookiesController,
        Base::App::Preference::ThemesController,
        Base::App::Preference::CurrenciesController,
        Base::App::Preference::CalendarsController,
        Base::App::Preference::ClocksController,
        Base::App::Preference::MotionsController,
        Base::App::Preference::DensitiesController,
        Base::App::Preference::PaginationsController,
        Base::App::Preference::LanguagesController,
        Base::App::Preference::TimezonesController,
        Base::App::Preference::RegionsController,
        Base::App::Preference::ScreensController,
      ],
      "base/org" => [
        Base::Org::Api::V0::Preferences::CookiesController,
        Base::Org::Api::V0::Preferences::ThemesController,
        Base::Org::Preference::CookiesController,
        Base::Org::Preference::ThemesController,
        Base::Org::Preference::CurrenciesController,
        Base::Org::Preference::CalendarsController,
        Base::Org::Preference::ClocksController,
        Base::Org::Preference::MotionsController,
        Base::Org::Preference::DensitiesController,
        Base::Org::Preference::PaginationsController,
        Base::Org::Preference::LanguagesController,
        Base::Org::Preference::TimezonesController,
        Base::Org::Preference::RegionsController,
        Base::Org::Preference::ScreensController,
      ],
    }.each do |surface_key, controllers|
      realm = surface_key.split("/").last.to_sym
      controllers.each do |controller|
        result = PreferenceWriteBoundary.authorize_writer!(
          controller:, action: "update", surface_key:, operation: :save,
          realm_model: REALM_MODELS.fetch(realm),
        )

        assert_equal [realm, :save], result.values_at(:realm, :operation)
      end

      reset_controller =
        case realm
        when :com then Base::Com::Preference::CustomizationsController
        when :app then Base::App::Preference::CustomizationsController
        when :org then Base::Org::Preference::CustomizationsController
        end
      result = PreferenceWriteBoundary.authorize_writer!(
        controller: reset_controller, action: "destroy", surface_key:, operation: :reset,
        realm_model: REALM_MODELS.fetch(realm),
      )

      assert_equal [realm, :reset], result.values_at(:realm, :operation)
    end
  end

  test "static writer authorization refuses cross-realm and non-preference callers" do
    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::Preference::CookiesController, action: "update", surface_key: "base/org",
        operation: :save, realm_model: OrgPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::RootsController, action: "update", surface_key: "base/app",
        operation: :save, realm_model: AppPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::Preference::CookiesController, action: "update", surface_key: "base/app",
        operation: :sign_in, realm_model: AppPreference,
      )
    end
  end
end
