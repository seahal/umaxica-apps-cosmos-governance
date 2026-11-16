# typed: false
# frozen_string_literal: true

require "test_helper"

# Base and Tech declare their own default web limiter on each application
# controller, with separate scope names, and the limiter is the only thing
# standing between an unauthenticated caller and unbounded traffic to that
# surface. A scope name that collides with another surface, a store that is not
# wired up, or a refusal handler that is never reached all look like a passing
# suite otherwise, because nothing else exercises the limiter itself.
#
# Each case sends the full quota and then one more request, so it also pins that
# the quota is not off by one in either direction.
class SurfaceDefaultWebRateLimitTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  self.fixture_table_names = []

  DEFAULT_WEB_QUOTA = 300

  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = {
    "base app" => [HOSTS.base_service.host, :base_app_root_path],
    "base com" => [HOSTS.base_corporate.host, :base_com_root_path],
    "base org" => [HOSTS.base_staff.host, :base_org_root_path],
    "tech org" => [HOSTS.tech_staff.host, :tech_org_root_path],
  }.freeze

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  SURFACES.each do |surface, (host, helper)|
    test "#{surface} answers the request past its default web quota with a retry hint" do
      host! host

      DEFAULT_WEB_QUOTA.times { get public_send(helper, ri: "jp") }

      assert_not_equal 429, response.status,
                       "#{surface} refused a request inside its quota of #{DEFAULT_WEB_QUOTA}"

      get public_send(helper, ri: "jp")

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
