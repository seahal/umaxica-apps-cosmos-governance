# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Base
  class DomainStructureTest < ActionDispatch::IntegrationTest
    test "base/org guards unsafe Browser RP requests before surface callbacks" do
      callbacks = Base::Org::ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

      assert_includes before_filters, :guard_browser_rp_unsafe_request!
      assert_not_includes before_filters, :authenticate_browser_rp_safe_request!
      assert_not_includes before_filters, :transparent_refresh_access_token
    end
  end
end
