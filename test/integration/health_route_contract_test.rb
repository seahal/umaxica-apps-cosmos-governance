# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HealthRouteContractTest < ActionDispatch::IntegrationTest
  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  GOVERNANCE_HOSTS = [HOSTS.base_service.host, HOSTS.base_corporate.host, HOSTS.base_staff.host,
                      HOSTS.tech_staff.host,].freeze

  # The probe contract was unified on /health/liveness and /health/readiness.
  # The former /health/live and /health/ready paths were removed outright (no
  # compatibility shim); guard against their reintroduction on any surface.
  test "removed legacy probe paths are not routed" do
    GOVERNANCE_HOSTS.each do |host|
      %w(/health/live /health/ready).each do |path|
        assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end

  # The machine endpoints carry the literal ".json" as a path segment (`format: false`). The
  # bare paths and any other API version must not resolve.
  test "machine health and revision endpoints exist only at the exact /api/v0/*.json paths" do
    GOVERNANCE_HOSTS.each do |host|
      %w(
        /api/v0/health /api/v0/revision /api/v1/health.json /api/v1/revision.json
        /api/v0/liveness.json /health.json/liveness
      ).each do |path|
        assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end
end
