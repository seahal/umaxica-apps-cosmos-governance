# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutControllerContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CONTROLLERS = {
    "app/controllers/base/app/application_controller.rb" => ["Base::App::ApplicationController",
                                                             "base/app/application",],
    "app/controllers/base/com/application_controller.rb" => ["Base::Com::ApplicationController",
                                                             "base/com/application",],
    "app/controllers/base/org/application_controller.rb" => ["Base::Org::ApplicationController",
                                                             "base/org/application",],
    "app/controllers/tech/org/application_controller.rb" => ["Tech::Org::ApplicationController",
                                                             "tech/org/application",],
  }.freeze

  test "Base and Tech application controllers declare literal layouts" do
    CONTROLLERS.each do |path, (controller_name, layout_name)|
      contents = Rails.root.join(path).read
      controller = controller_name.safe_constantize

      assert_predicate controller, :present?
      assert_equal layout_name, controller._layout
      assert_includes contents, %(layout "#{layout_name}"), "missing literal layout declaration in #{path}"
      assert_no_match(
        /\blayout\s*(?:->|do|proc|lambda|method)/, contents,
        "layout declaration in #{path} must stay literal",
      )
    end
  end
end
