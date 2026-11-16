# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "rake"
require_relative "../../lib/architecture_baseline"

# Ratchet for the Umaxica architecture cops.
#
# This test measures the repository with the architecture cops' normal configuration and compares
# against the recorded per-file counts. There are no TODO exclusions; RuboCop rejects every new
# violation directly. Regenerate the count inventory only after reducing debt with
# `bin/rails architecture:baseline`.
class ArchitectureBaselineTest < ActiveSupport::TestCase
  parallelize(workers: 1, parallelize_databases: false)

  def test_architecture_baseline_task_writes_its_measured_counts
    counts_path = ArchitectureBaseline::COUNTS_PATH
    original_contents = File.binread(counts_path)

    begin
      expected_counts = ArchitectureBaseline.measure
      Rake.application.rake_require(
        "tasks/architecture_baseline", [File.expand_path("../../lib", __dir__)],
      )
      task = Rake::Task["architecture:baseline"]
      task.reenable
      task.invoke

      assert_equal expected_counts, ArchitectureBaseline.recorded
    ensure
      File.binwrite(counts_path, original_contents)
    end
  end

  def test_no_file_exceeds_its_recorded_architecture_debt
    measured = ArchitectureBaseline.measure
    recorded = ArchitectureBaseline.recorded

    ArchitectureBaseline::COPS.each do |cop|
      recorded_files = recorded.fetch(cop)

      assert_empty measured.fetch(cop), "#{cop} must have no remaining offenses."

      measured.fetch(cop).each do |path, count|
        allowed = recorded_files.fetch(path, 0)

        assert_operator count, :<=, allowed,
                        "#{path} has #{count} #{cop} offenses but the baseline allows #{allowed}. " \
                        "Fix the new violation; do not regenerate the baseline to hide it."
      end
    end
  end

  def test_no_architecture_todo_exclusions_remain
    recorded = ArchitectureBaseline.recorded
    rubocop_config = YAML.load_file(ArchitectureBaseline::ROOT.join(".rubocop.yml"), aliases: false)

    assert_not_predicate ArchitectureBaseline::ROOT.join(".rubocop_todo.yml"), :exist?,
                         "Remove the architecture TODO file after its recorded offenses reach zero."
    assert_not_includes Array(rubocop_config.fetch("inherit_from")), ".rubocop_todo.yml"
    assert_empty recorded.fetch("Umaxica/NoConcernInclusionHooks")
    assert_empty recorded.fetch("Umaxica/ExplicitMethodVisibility")
  end

  def test_baseline_does_not_list_resolved_files
    measured = ArchitectureBaseline.measure

    ArchitectureBaseline::COPS.each do |cop|
      stale = ArchitectureBaseline.recorded.fetch(cop).keys - measured.fetch(cop).keys

      assert_empty stale,
                   "#{cop} baseline lists files with no remaining offenses. " \
                   "Run bin/rails architecture:baseline to drop them."
    end
  end
end
