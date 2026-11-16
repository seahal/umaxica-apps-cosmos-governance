# frozen_string_literal: true

require "test_helper"

class DomainAuthorityProtocolTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Base authority lookup accepts only active actor realms" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    assert_equal hosts.base_service, hosts.base_for_resource_type("client")
    assert_equal hosts.base_staff, hosts.base_for_resource_type("operator")
    assert_equal hosts.base_staff, hosts.base_for_resource_type("staff")
    [nil, "", false, "unknown", "visitor", "customer"].each do |resource_type|
      assert_raises(ArgumentError) { hosts.base_for_resource_type(resource_type) }
    end
  end

  test "identity authority clients reject retired and unknown surfaces before making a request" do
    request = ActionDispatch::TestRequest.create
    %w(app org).each do |surface|
      assert_instance_of AvatarAuthorityClient,
                         AvatarAuthorityClient.new(
                           surface: surface, rp_session: RpBaseAppSession.new,
                           persona: "person",
                         )
      assert_instance_of MembershipAuthorityClient,
                         MembershipAuthorityClient.new(
                           surface: surface, rp_session: RpBaseAppSession.new,
                           persona: "person",
                         )
    end
    ["com", "", "unknown", nil].each do |surface|
      assert_raises(KeyError) {
        AvatarAuthorityClient.new(surface: surface, rp_session: RpBaseAppSession.new, persona: "person")
      }
      assert_raises(KeyError) do
        MembershipAuthorityClient.new(surface: surface, rp_session: RpBaseAppSession.new, persona: "person")
      end
      assert_raises(KeyError) do
        OrgAdminAuthorityClient.new(surface: surface, rp_session: RpBaseOrgSession.new, browser_request: request)
      end
    end
  end

  test "group lookup escapes the reference as one path segment and preserves owner refusals" do
    connection = Faraday.new
    reference = "../other?admin=true#fragment"
    [200, 403, 404].each do |status|
      response = Faraday::Response.new(status: status, body: { group: "synthetic" }.to_json)
      fetch =
        lambda do |uri, params, _headers|
          assert_equal "/api/v0/avatar/app/groups/#{ERB::Util.url_encode(reference)}", uri.path
          assert_nil uri.query
          assert_nil uri.fragment
          assert_equal "persona", params.fetch(:persona)
          response
        end
      BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:get, fetch) do
            result = AvatarAuthorityClient.new(
              surface: "app", rp_session: RpBaseAppSession.new, persona: "persona",
            ).fetch_group(reference)

            assert_equal({ 200 => :ok, 403 => :forbidden, 404 => :not_found }.fetch(status), result.status)
          end
        end
      end
    end
  end

  test "APP Avatar requests carry the complete RP-selected context for owner verification" do
    selection = Actor::SelectedContext.new(
      account_public_id: "persona-public-id",
      collective_public_id: "organization-public-id",
      collective_unit_public_id: "unit-public-id",
      avatar_public_id: "avatar-public-id",
    )
    connection = Faraday.new
    response = Faraday::Response.new(status: 200, body: { groups: [] }.to_json)
    request =
      lambda do |uri, params, _headers|
        assert_equal "/api/v0/avatar/app/groups", uri.path
        assert_equal(
          {
            persona: "persona-public-id",
            organization_public_id: "organization-public-id",
            organization_unit_public_id: "unit-public-id",
            avatar_public_id: "avatar-public-id",
          },
          params,
        )
        response
      end

    BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, request) do
          result = AvatarAuthorityClient.new(
            surface: "app", rp_session: RpBaseAppSession.new, persona: "persona-public-id", selection:,
          ).groups

          assert_predicate result, :ok?
          assert_equal [], result.data.fetch("groups")
        end
      end
    end
  end

  test "domain clients preserve owner objects and refuse non-object JSON as dependency failures" do
    browser_request = ActionDispatch::TestRequest.create
    clients = [
      -> { AvatarAuthorityClient.new(surface: "app", rp_session: RpBaseAppSession.new, persona: "persona").groups },
      -> {
        MembershipAuthorityClient.new(surface: "app", rp_session: RpBaseAppSession.new, persona: "persona").accounts
      },
      -> {
        OrgAdminAuthorityClient.new(
          rp_session: RpBaseOrgSession.new,
          browser_request: browser_request,
        ).get("/iam/grants")
      },
    ]
    connection = Faraday.new
    [{ "items" => [] }, [], nil, true, 1, "invalid-object"].each do |body|
      response = Faraday::Response.new(status: 200, body: body.to_json)
      clients.each do |call|
        BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:get, response) do
              result = call.call
              if body.is_a?(Hash)
                assert_predicate result, :ok?
                assert_equal body, result.data
              else
                assert_equal :dependency, result.status
                assert_nil result.data
              end
            end
          end
        end
      end
    end
  end

  test "Tech requires an explicit boolean allow in an object and refuses other JSON shapes" do
    connection = Faraday.new
    [{ "allowed" => true }, { "allowed" => false }, { "allowed" => "true" }, {}, [], nil, true, 1].each do |body|
      response = Faraday::Response.new(status: 200, body: body.to_json)
      BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, response) do
            if body.is_a?(Hash) && [true, false].include?(body["allowed"])
              assert_equal body["allowed"], TechCapabilityClient.allowed?(rp_session: RpTechOrgSession.new)
            else
              assert_raises(AccessOpDataUnavailableError) {
                TechCapabilityClient.allowed?(rp_session: RpTechOrgSession.new)
              }
            end
          end
        end
      end
    end
  end

  test "Tech reaches the Base staff capability check through the local back channel" do
    connection = Faraday.new
    built = []
    posted = []
    response = Faraday::Response.new(status: 200, body: { "allowed" => true }.to_json)
    BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
      OutboundHttp::Connection.stub(:build, ->(**options) { (built << options) && connection }) do
        connection.stub(
          :post, ->(uri, body, headers) {
                   posted << [uri.to_s, body, headers]
                   response
                 },
        ) do
          assert TechCapabilityClient.allowed?(rp_session: RpTechOrgSession.new)
        end
      end
    end
    sent = URI.parse(posted.sole.fetch(0))
    base_host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host

    assert_equal ["http", base_host, Integer(ENV.fetch("PORT"), exception: false) || 3000,
                  "/api/v0/tech-capability-checks", false,],
                 [sent.scheme, sent.host, sent.port, sent.path, built.sole.fetch(:require_https)]
    assert_equal({}, posted.sole.fetch(1))
    assert_equal "Bearer synthetic-governance-token", posted.sole.fetch(2).fetch("Authorization")
    assert_not posted.sole.fetch(2).key?("X-Client-Assertion")
  end
  test "Tech distinguishes permission refusal from unavailable authority status" do
    connection = Faraday.new
    [401, 403, 500, 503].each do |status|
      response = Faraday::Response.new(status:, body: "{}")
      BaseApiAuthorityTokenIssuer.stub(:issue, "synthetic-governance-token") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, response) do
            if [401, 403].include?(status)
              assert_not TechCapabilityClient.allowed?(rp_session: RpTechOrgSession.new)
            else
              assert_raises(AccessOpDataUnavailableError) {
                TechCapabilityClient.allowed?(rp_session: RpTechOrgSession.new)
              }
            end
          end
        end
      end
    end
  end
end
