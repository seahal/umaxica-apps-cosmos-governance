# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthorityBoundaryTest < ActiveSupport::TestCase
  test "Base self-RP controllers retain browser RP lifecycle and inherit no root authentication" do
    [Base::App::ApplicationController, Base::Org::ApplicationController].each do |controller|
      assert_includes controller.ancestors, BrowserRpAuthentication, controller.name
      assert_equal :deny_all, controller.authentication_mode_for(:index), controller.name
    end
  end
end
