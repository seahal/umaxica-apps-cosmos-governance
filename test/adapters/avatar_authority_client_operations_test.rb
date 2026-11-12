# frozen_string_literal: true

require "test_helper"

class AvatarAuthorityClientOperationsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "avatar index and member reads preserve selected owner context" do
    selection = Actor::SelectedContext.new(
      account_public_id: "persona-public-id",
      collective_public_id: "organization-public-id",
      collective_unit_public_id: "unit-public-id",
      avatar_public_id: "avatar-public-id",
    )
    connection = Faraday.new
    reference = "../other?admin=true#fragment"
    requests = []
    response = Faraday::Response.new(status: 200, body: { avatars: [] }.to_json)
    request =
      lambda do |uri, params, headers|
        requests << [uri, params, headers]
        response
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, request) do
          client = AvatarAuthorityClient.new(
            surface: "app", access_token: "test-access-token", persona: "persona-public-id", selection:,
          )

          assert_predicate client.avatars, :ok?
          assert_predicate client.avatar(reference), :ok?
        end
      end
    end

    collection_uri, collection_params, collection_headers = requests.fetch(0)
    member_uri, member_params, member_headers = requests.fetch(1)

    assert_equal "/api/v0/avatar/app/avatars", collection_uri.path
    assert_nil collection_uri.query
    assert_equal "/api/v0/avatar/app/avatars/#{ERB::Util.url_encode(reference)}", member_uri.path
    assert_nil member_uri.query
    assert_nil member_uri.fragment
    expected_selection = {
      persona: "persona-public-id",
      organization_public_id: "organization-public-id",
      organization_unit_public_id: "unit-public-id",
      avatar_public_id: "avatar-public-id",
    }

    assert_equal expected_selection, collection_params
    assert_equal expected_selection, member_params
    [collection_headers, member_headers].each do |headers|
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
      assert_equal "application/json", headers.fetch("Accept")
    end
  end

  test "avatar create and update send nested attributes to escaped owner routes" do
    connection = Faraday.new
    reference = "../other?admin=true#fragment"
    attributes = { display_name: "Visible name", description: "Public profile" }
    requests = []
    responses = [
      Faraday::Response.new(status: 201, body: { avatar: { public_id: "avatar-public-id" } }.to_json),
      Faraday::Response.new(status: 200, body: { avatar: { public_id: "avatar-public-id" } }.to_json),
    ]
    request =
      lambda do |verb, uri, body, headers|
        requests << [verb, uri, Rack::Utils.parse_nested_query(body), headers]
        responses.shift
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          client = AvatarAuthorityClient.new(
            surface: "app", access_token: "test-access-token", persona: "persona-public-id",
          )

          assert_equal :ok, client.create_avatar(attributes).status
          assert_equal :ok, client.update_avatar(reference, attributes).status
        end
      end
    end

    create_verb, create_uri, create_body, create_headers = requests.fetch(0)
    update_verb, update_uri, update_body, update_headers = requests.fetch(1)

    assert_equal :post, create_verb
    assert_equal "/api/v0/avatar/app/avatars", create_uri.path
    expected_avatar_write = {
      "avatar" => { "display_name" => "Visible name", "description" => "Public profile" },
      "avatar_public_id" => nil,
      "organization_public_id" => nil,
      "organization_unit_public_id" => nil,
      "persona" => "persona-public-id",
    }

    assert_equal expected_avatar_write, create_body
    assert_equal :patch, update_verb
    assert_equal "/api/v0/avatar/app/avatars/#{ERB::Util.url_encode(reference)}", update_uri.path
    assert_nil update_uri.query
    assert_nil update_uri.fragment
    assert_equal expected_avatar_write, update_body
    [create_headers, update_headers].each do |headers|
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
      assert_equal "application/x-www-form-urlencoded", headers.fetch("Content-Type")
    end
  end

  test "avatar edges use the requested relationship and preserve owner refusal" do
    connection = Faraday.new
    target = "../other?admin=true#fragment"
    requests = []
    responses = [
      Faraday::Response.new(status: 204, body: ""),
      Faraday::Response.new(status: 403, body: { errors: { base: ["forbidden"] } }.to_json),
    ]
    request =
      lambda do |verb, uri, body, headers|
        requests << [verb, uri, Rack::Utils.parse_nested_query(body), headers]
        responses.shift
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          client = AvatarAuthorityClient.new(
            surface: "org", access_token: "test-access-token", persona: "operator-public-id",
          )

          assert_equal :ok, client.add_edge("follows", target).status
          refusal = client.remove_edge("blocks", target)

          assert_equal :forbidden, refusal.status
          assert_equal({ "base" => ["forbidden"] }, refusal.errors)
        end
      end
    end

    add_verb, add_uri, add_body, add_headers = requests.fetch(0)
    remove_verb, remove_uri, remove_body, remove_headers = requests.fetch(1)

    assert_equal :post, add_verb
    assert_equal "/api/v0/avatar/org/avatars/#{ERB::Util.url_encode(target)}/follows", add_uri.path
    assert_nil add_uri.query
    assert_nil add_uri.fragment
    assert_equal({ "persona" => "operator-public-id" }, add_body)
    assert_equal :delete, remove_verb
    assert_equal "/api/v0/avatar/org/avatars/#{ERB::Util.url_encode(target)}/blocks", remove_uri.path
    assert_equal({ "persona" => "operator-public-id" }, remove_body)
    [add_headers, remove_headers].each do |headers|
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
    end
  end

  test "ownership transfer forwards the idempotency key unchanged" do
    connection = Faraday.new
    attributes = { source_avatar_public_id: "source-avatar", target_avatar_public_id: "target-avatar" }
    idempotency_key = "registry-request-7d2b"
    response = Faraday::Response.new(status: 201, body: { transfer: { public_id: "transfer-public-id" } }.to_json)
    request =
      lambda do |verb, uri, body, headers|
        assert_equal :post, verb
        assert_equal "/api/v0/avatar/org/ownership-transfers", uri.path
        assert_equal(
          { "source_avatar_public_id" => "source-avatar",
            "target_avatar_public_id" => "target-avatar",
            "persona" => "operator-public-id", }, Rack::Utils.parse_nested_query(body),
        )
        assert_equal idempotency_key, headers.fetch("Idempotency-Key")
        assert_equal "Bearer test-access-token", headers.fetch("Authorization")
        assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
        response
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          result = AvatarAuthorityClient.new(
            surface: "org", access_token: "test-access-token", persona: "operator-public-id",
          ).request_transfer(attributes, idempotency_key:)

          assert_equal :ok, result.status
          assert_equal "transfer-public-id", result.data.dig("transfer", "public_id")
        end
      end
    end
  end

  test "switcher reads and updates use the organization context" do
    selection = Actor::SelectedContext.new(
      account_public_id: "operator-public-id",
      collective_public_id: "organization-public-id",
      collective_unit_public_id: "unit-public-id",
      avatar_public_id: "avatar-public-id",
    )
    connection = Faraday.new
    requests = []
    responses = [
      Faraday::Response.new(status: 200, body: { current: {} }.to_json),
      Faraday::Response.new(status: 200, body: { status: "switched" }.to_json),
    ]
    read_request =
      lambda do |uri, params, headers|
        requests << [:get, uri, params, headers]
        responses.shift
      end
    update_request =
      lambda do |verb, uri, body, headers|
        requests << [verb, uri, Rack::Utils.parse_nested_query(body), headers]
        responses.shift
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, read_request) do
          connection.stub(:run_request, update_request) do
            client = AvatarAuthorityClient.new(
              surface: "org", access_token: "test-access-token", persona: "operator-public-id", selection:,
            )

            assert_equal :ok, client.switcher_context.status
            assert_equal :ok, client.switch_context({ organization_public_id: "next-organization" }).status
          end
        end
      end
    end

    read_verb, read_uri, read_params, read_headers = requests.fetch(0)
    update_verb, update_uri, update_body, update_headers = requests.fetch(1)

    assert_equal :get, read_verb
    assert_equal "/api/v0/avatar/org/switcher", read_uri.path
    assert_equal(
      { persona: "operator-public-id",
        organization_public_id: "organization-public-id",
        organization_unit_public_id: "unit-public-id",
        avatar_public_id: "avatar-public-id", }, read_params,
    )
    assert_equal :put, update_verb
    assert_equal "/api/v0/avatar/org/switcher", update_uri.path
    assert_equal(
      { "organization_public_id" => "next-organization",
        "persona" => "operator-public-id", }, update_body,
    )
    [read_headers, update_headers].each do |headers|
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
    end
  end

  test "selected avatar reads and updates use the organization-only endpoint" do
    connection = Faraday.new
    attributes = { public_id: "replacement-avatar" }
    requests = []
    responses = [
      Faraday::Response.new(status: 200, body: { avatar: { public_id: "selected-avatar" } }.to_json),
      Faraday::Response.new(status: 200, body: { avatar: { public_id: "replacement-avatar" } }.to_json),
    ]
    read_request =
      lambda do |uri, params, headers|
        requests << [:get, uri, params, headers]
        responses.shift
      end
    update_request =
      lambda do |verb, uri, body, headers|
        requests << [verb, uri, Rack::Utils.parse_nested_query(body), headers]
        responses.shift
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, read_request) do
          connection.stub(:run_request, update_request) do
            client = AvatarAuthorityClient.new(
              surface: "org", access_token: "test-access-token", persona: "operator-public-id",
            )

            assert_equal :ok, client.selected_avatar.status
            assert_equal :ok, client.update_selected_avatar(attributes).status
          end
        end
      end
    end

    read_verb, read_uri, read_params, read_headers = requests.fetch(0)
    update_verb, update_uri, update_body, update_headers = requests.fetch(1)

    assert_equal :get, read_verb
    assert_equal "/api/v0/avatar/org/selected-avatar", read_uri.path
    assert_equal({ persona: "operator-public-id" }, read_params)
    assert_equal :patch, update_verb
    assert_equal "/api/v0/avatar/org/selected-avatar", update_uri.path
    assert_equal(
      { "avatar" => { "public_id" => "replacement-avatar" },
        "persona" => "operator-public-id", }, update_body,
    )
    [read_headers, update_headers].each do |headers|
      assert_equal "Bearer test-access-token", headers.fetch("Authorization")
      assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
    end
  end
end
