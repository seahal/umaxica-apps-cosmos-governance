# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrivateAuthorizationPostconditionInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "owned surface controllers verify authorization after private actions" do
        controller_sources = %w(
          app/controllers/base/app/application_controller.rb
          app/controllers/base/org/application_controller.rb
          app/controllers/tech/org/application_controller.rb
        )

        controller_sources.each do |path|
          assert_includes Rails.root.join(path).read, "after_action :verify_private_action_authorized!", path
        end

        authentication_source = Rails.root.join("app/controllers/concerns/browser_rp_authentication.rb").read

        assert_includes authentication_source, "def verify_private_action_authorized!"
        assert_includes authentication_source, "self.class.authentication_mode_for(action_name) == :private"
        assert_includes authentication_source, "verify_authorized"
      end

      test "authorization postcondition bypass APIs are absent from application controllers" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").filter do |path|
            path.read.match?(/skip_verify_authorized|skip_after_action\s+:verify_private_action_authorized/)
          end

        assert_empty offenders
      end
    end
  end
end
