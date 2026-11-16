# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  class AuthenticationModeInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    class ParentController < ApplicationController
      include BrowserRpAuthentication

      declare_authentication_mode! :open
    end

    class UndeclaredController < ParentController
    end

    class ConstantController < ApplicationController
      include BrowserRpAuthentication

      AUTHENTICATION_MODE = :guest
    end

    class PrivateController < ApplicationController
      include BrowserRpAuthentication

      declare_authentication_mode! :private
    end

    class MixedController < ApplicationController
      include BrowserRpAuthentication

      declare_authentication_mode! :deny_all
      declare_authentication_mode! :open, only: :index
      declare_authentication_mode! :guest, only: :new
    end

    test "undeclared concrete controllers resolve to deny_all instead of inheriting parent mode" do
      assert_equal :open, ParentController.authentication_mode_for(:index)
      assert_empty UndeclaredController.local_authentication_mode_rules
      assert_equal :deny_all, UndeclaredController.authentication_mode_for(:index)
    end

    test "private authentication mode declarations resolve through browser RP metadata" do
      assert_equal :private, PrivateController.authentication_mode_for(:show)
    end

    test "local AUTHENTICATION_MODE constant is honored without inheritance" do
      assert_equal :guest, ConstantController.authentication_mode_for(:show)
    end

    test "action-specific authentication mode rules override the deny_all default" do
      assert_equal :open, MixedController.authentication_mode_for(:index)
      assert_equal :guest, MixedController.authentication_mode_for(:new)
      assert_equal :deny_all, MixedController.authentication_mode_for(:show)
    end

    test "Base and Tech application controllers default to deny_all" do
      [
        Base::App::ApplicationController,
        Base::Org::ApplicationController,
        Tech::Org::ApplicationController,
      ].each do |controller_class|
        assert_equal :deny_all, controller_class.authentication_mode_for(:index), controller_class.name
      end
    end

    # The Base com surface has no authentication boundary; Base app, Base org, and Tech org do.
    test "controller files declare a local authentication mode" do
      missing =
        Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
          controller_class = controller_class_for(path)
          next unless controller_class&.include?(BrowserRpAuthentication)

          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          relative_path unless content.match?(/\bAUTHENTICATION_MODE\s*=/)
        end

      assert_empty missing, "Controllers must declare local AUTHENTICATION_MODE:\n#{missing.join("\n")}"
    end

    test "controller files do not use legacy authentication posture DSL" do
      legacy =
        Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          matches = content.scan(/\b(?:deny_all!|public_strict!|auth_required!|guest_only!)/)
          "#{relative_path}: #{matches.uniq.join(", ")}" if matches.any?
        end

      assert_empty legacy, "Controllers must use AUTHENTICATION_MODE instead of legacy DSL:\n#{legacy.join("\n")}"
    end

    test "browser RP authentication has no parallel access policy declaration path" do
      concern = Rails.root.join("app/controllers/concerns/browser_rp_authentication.rb").read

      assert_no_match(/\b(?:AccessPolicyContext|ACCESS_POLICY_RULES|def\s+access_policy(?:_rules)?)\b/, concern)

      legacy_policies =
        Rails.root.glob("app/policies/**/*.rb").filter_map do |path|
          path.relative_path_from(Rails.root).to_s if File.read(path).match?(/\bclass\s+AccessPolicy\b/)
        end

      assert_empty legacy_policies, "Authentication-mode policy classes are obsolete: #{legacy_policies.join(", ")}"
    end

    test "bare controllers inherit directly from action controller base" do
      violations =
        Rails.root.glob("app/controllers/**/bare_controller.rb").filter_map do |path|
          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          relative_path unless content.match?(/class\s+BareController\s+<\s+ActionController::Base\b/)
        end

      assert_empty violations,
                   "Bare controllers must inherit ActionController::Base directly:\n#{violations.join("\n")}"
    end

    test "routes resolve to controllers with local authentication mode declarations" do
      missing =
        Rails.application.routes.routes.filter_map do |route|
          controller_name = route.defaults[:controller]
          action_name = route.defaults[:action]
          next if controller_name.blank? || action_name.blank?
          # Development-only inertia_rails DevTools; RuntimeRoleRouteOwnershipTest shows these
          # routes do not match outside development.
          next if controller_name == "inertia_rails/devtools/entries"

          controller_class = "#{controller_name.camelize}Controller".safe_constantize
          next if controller_class.blank?
          next unless application_controller_class?(controller_class)
          # Anonymous com controllers carry no authentication boundary to declare.
          next unless controller_class.include?(BrowserRpAuthentication)
          next if controller_class.const_defined?(:AUTHENTICATION_MODE, false)
          next if controller_class.respond_to?(:local_authentication_mode_rules) &&
            controller_class.local_authentication_mode_rules.present?

          "#{route.verb.presence || "ANY"} #{route.path.spec} => #{controller_class.name}##{action_name}"
        end

      assert_empty missing, "Routes must not rely on inherited authentication mode:\n#{missing.join("\n")}"
    end

    private

    def controller_class_for(path)
      relative = path.relative_path_from(Rails.root.join("app/controllers")).to_s.delete_suffix(".rb")
      "#{relative.camelize}Controller".safe_constantize
    end

    def application_controller_class?(controller_class)
      controller_class.name.start_with?("Base::", "Tech::")
    end
  end
end
