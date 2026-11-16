# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Concerns
  class ApplicationControllerCommonPatternsTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    ALL_CONTROLLER_FILES = Dir.glob(Rails.root.join("app/controllers/**/application_controller.rb").to_s)
      .reject { |f| f.include?("/vendor/") }
      .reject { |f| f.end_with?("/controllers/application_controller.rb") }
      .reject { |f| f.include?("/sign/com/") }
      .reject { |f| f.include?("/jump/") }
      .reject { |f| f.include?("/palm/") }
      .sort
    CONTROLLER_FILES =
      ALL_CONTROLLER_FILES.index_with do |file|
        {
          content: File.read(file),
          name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::")
            .gsub("_", " ")
            .split.map(&:capitalize).join("::"),
          path_name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::"),
        }
      end

    test "all application controllers include RateLimit" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "RateLimit",
                        "#{controller_name} should include RateLimit"
      end
    end

    test "all application controllers include an actor lifecycle" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert(
          content.include?("ActorSupport") || content.include?("ComAnonymousActorContext"),
          "#{controller_name} should include ActorSupport or ComAnonymousActorContext",
        )
      end
    end

    test "all application controllers include Session" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "Session",
                        "#{controller_name} should include Session"
      end
    end

    test "all application controllers include Finisher" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "Finisher",
                        "#{controller_name} should include Finisher"
      end
    end

    test "all application controllers have cleanup action" do
      pattern = %r{
        (after_action|append_after_action)\s+:(purge_current|finish_request)
        |
        (prepend_around_action|around_action)\s+:(with_actor_lifecycle|with_anonymous_context_lifecycle)
    }x

      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_match(
          pattern,
          content,
          "#{controller_name} should have cleanup action",
        )
      end
    end

    test "application controllers do not register removed default rate limit callback" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_not_includes content, "before_action :check_default_rate_limit",
                            "#{controller_name} should not use removed default rate limit callback"
      end
    end

    test "all application controllers set current context before reset flash" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_match(
          /before_action :(set_current_context|set_anonymous_context)\s+before_action :reset_flash/,
          content,
          "#{controller_name} should set current context before reset flash",
        )
      end
    end

    # Base com stays public and does not establish a visitor credential boundary.
    test "no application controller authenticates a visitor" do
      CONTROLLER_FILES.each_value do |controller|
        assert_not_includes controller[:content], "AuthenticationVisitor",
                            "#{controller[:path_name]} must not authenticate a visitor"
      end
    end

    # Controllers that run the full authenticated request lifecycle are marked by
    # enforce_access_policy!. dev/net/palm bare bases do not run it and are excluded.
    def lifecycle_controllers
      CONTROLLER_FILES.values.select do |controller|
        controller[:content].include?("enforce_access_policy!")
      end
    end

    # Wedge: every full-lifecycle surface controller must reflect the request locale.
    # Regression guard against the com/org surfaces silently dropping set_locale again.
    test "all lifecycle application controllers reflect locale" do
      lifecycle_controllers.each do |controller|
        assert_match(
          /before_action :set_locale$/,
          controller[:content],
          "#{controller[:path_name]} should run set_locale (locale drift guard)",
        )
      end
    end

    # Wedge: the retired session-limit placeholder must not reintroduce a controller guard.
    test "lifecycle application controllers do not register the retired restricted-session guard" do
      lifecycle_controllers.each do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_not_includes content, "RestrictedSessionGuard",
                            "#{controller_name} reintroduced the retired restricted-session guard"
        assert_no_match(
          /before_action :enforce_restricted_session_guard!$/,
          content,
          "#{controller_name} reintroduced the retired restricted-session callback",
        )
      end
    end

    # Base App remains the only Governance app lifecycle controller after route separation.
    test "Base App lifecycle reflects timezone" do
      app_controllers =
        lifecycle_controllers.select { |controller| controller[:path_name].end_with?("::app") }

      assert_equal ["base::app"], app_controllers.pluck(:path_name)

      app_controllers.each do |controller|
        assert_match(
          /before_action :set_timezone$/,
          controller[:content],
          "#{controller[:path_name]} should run set_timezone (timezone drift guard)",
        )
      end
    end
  end
end
