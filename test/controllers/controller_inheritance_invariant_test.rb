# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Every app controller inherits directly from an approved Rails or surface controller base.
# Controller-to-controller inheritance is forbidden.
class ControllerInheritanceInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Scans all controller source files and returns paths (relative to Rails.root)
  # whose class declaration inherits from a non-approved base.
  # Approved bases: ApplicationController, BareController, ActionController::Base,
  # PreAccessController, FullAccessController, and PreferencesBaseController.
  APPROVED_BASE_PATTERN = /
    ApplicationController
    | BareController
    | ActionController
    | PreAccessController
    | FullAccessController
    | PreferencesBaseController
    | ::Base\b
    | BaseController\b
  /x

  test "controllers do not inherit from other controllers" do
    violations = detect_inheritance_violations

    assert_empty violations,
                 "Controller-to-controller inheritance is forbidden:\n#{violations.sort.join("\n")}"
  end

  private

  def detect_inheritance_violations
    Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
      relative = path.relative_path_from(Rails.root).to_s
      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      # Extract the inheritance clause from the class declaration.
      match = content.match(/class\s+\S+Controller\s*<\s*(\S+)/)
      next unless match

      superclass_ref = match[1]
      next if superclass_ref.match?(APPROVED_BASE_PATTERN)

      relative
    end.to_set
  end
end
