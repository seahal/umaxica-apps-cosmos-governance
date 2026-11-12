# frozen_string_literal: true

require "open3"
require "tmpdir"

repository = File.expand_path("..", __dir__)
surfaces = %w(app com org).freeze
failed = false

Dir.mktmpdir("umaxica-openapi-") do |temporary_directory|
  surfaces.each do |surface|
    generated_path = File.join(temporary_directory, "openapi.#{surface}.yml")
    _stdout, _stderr, status = Open3.capture3(
      "node_modules/.bin/redocly", "bundle", "openapi/#{surface}.yml", "--output", generated_path,
      chdir: repository,
    )

    unless status.success?
      warn "OpenAPI bundle generation failed for #{surface}."
      failed = true
      next
    end

    expected_path = File.join(repository, "openapi/bundled/openapi.#{surface}.yml")
    next if File.binread(generated_path) == File.binread(expected_path)

    warn "OpenAPI bundle is out of date for #{surface}."
    failed = true
  end
end

exit 1 if failed
