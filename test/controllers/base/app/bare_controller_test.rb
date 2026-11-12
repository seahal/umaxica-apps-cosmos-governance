# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseAppBareControllerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REQUIRED_DESCENDANTS = %w(
    Base::App::Api::V0::HealthsController
    Base::App::Api::V0::RevisionsController
    Base::App::CspViolationReportsController
    Base::App::Health::LivenessesController
    Base::App::Health::ReadinessesController
    Base::App::Health::StartupsController
    Base::App::HealthsController
    Base::App::Preference::EmailsController
    Base::App::RevisionsController
    Base::App::RobotsController
    Base::App::SitemapsController
    Base::App::WellKnown::JwksController
  ).freeze
  OPTIONAL_TEST_DESCENDANTS = %w(Base::App::TestCsrfController).freeze

  test "bare boundary does not inherit the full application controller" do
    assert_equal ActionController::Base, Base::App::BareController.superclass
    assert_not_operator Base::App::BareController, :<, Base::App::ApplicationController
  end

  test "only the reviewed allowlist inherits the bare public boundary" do
    Rails.application.eager_load!

    actual = Base::App::BareController.descendants.filter_map(&:name).grep(/\ABase::App::/).sort

    assert_not_empty actual, "expected Base::App::BareController descendants after eager load"

    allowed = (REQUIRED_DESCENDANTS + OPTIONAL_TEST_DESCENDANTS).sort
    unexpected = actual - allowed
    missing = REQUIRED_DESCENDANTS - actual

    assert_empty unexpected,
                 "Controllers under Base::App::BareController changed; review each public endpoint " \
                 "before updating the allowlist.\n" \
                 "added:   #{unexpected.inspect}\n" \
                 "removed: #{missing.inspect}"
    assert_empty missing
  end
end
