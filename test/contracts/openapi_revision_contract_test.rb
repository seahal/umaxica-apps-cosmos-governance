# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the machine-readable deployment identifier `GET /api/v0/revision.json` against each
# Governance route host and its surface description.
class OpenapiRevisionContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  REVISION = "0123456789abcdef0123456789abcdef01234567"

  ROUTE_SURFACES = [
    { label: "Base app", schema: "app", host: ENV.fetch("PUBLIC_BASE_SERVICE_URL") },
    { label: "Base com", schema: "com", host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL") },
    { label: "Base org", schema: "org", host: ENV.fetch("PUBLIC_BASE_STAFF_URL") },
    { label: "Tech org", schema: "org", host: ENV.fetch("PUBLIC_TECH_STAFF_URL") },
  ].freeze

  ROUTE_SURFACES.each do |route_surface|
    test "GET /api/v0/revision.json conforms to #{route_surface.fetch(:label)} with a revision" do
      self.openapi_surface = route_surface.fetch(:schema)
      host! route_surface.fetch(:host)

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal REVISION, response.parsed_body.fetch("revision")
      assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, response.parsed_body.fetch("timestamp"))
      assert_openapi_conform 200
    end

    test "GET /api/v0/revision.json conforms to #{route_surface.fetch(:label)} with a null revision" do
      self.openapi_surface = route_surface.fetch(:schema)
      host! route_surface.fetch(:host)

      Rails.application.stub(:revision, nil) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_nil response.parsed_body.fetch("revision")
      assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, response.parsed_body.fetch("timestamp"))
      assert_openapi_conform 200
    end

    test "GET /api/v0/revision.json refuses non-JSON Accept on #{route_surface.fetch(:label)}" do
      self.openapi_surface = route_surface.fetch(:schema)
      host! route_surface.fetch(:host)

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "text/plain" }
      end

      assert_response :not_acceptable
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "the revision member is described as a nullable string on every surface" do
    OpenapiContract::SURFACES.each do |surface|
      document = YAML.safe_load_file(OpenapiContract.schema_path(surface), aliases: true)
      get_op = document.dig("paths", "/api/v0/revision.json", "get")

      assert get_op, "#{surface} description is missing GET /api/v0/revision.json"

      schema = resolve_revision_schema(document, get_op)

      assert_equal "string", schema.fetch("type")
      assert schema.fetch("nullable"),
             "#{surface} revision member must be nullable: true (OpenAPI 3.0.4)"
    end
  end

  private

  def resolve_revision_schema(document, get_op)
    body_schema = get_op.dig("responses", "200", "content", "application/json", "schema")
    body_schema = dereference(document, body_schema)
    revision = body_schema.fetch("properties").fetch("revision")
    dereference(document, revision)
  end

  def dereference(document, node)
    ref = node["$ref"]
    return node unless ref

    pointer = ref.delete_prefix("#/").split("/")
    document.dig(*pointer)
  end
end
