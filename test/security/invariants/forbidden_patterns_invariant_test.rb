# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    class ForbiddenPatternsInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      FORBIDDEN_PATTERNS = {
        "mass-assignment permit!" => /\bpermit!/,
        "access policy bypass" => /skip_before_action\s+:enforce_access_policy!/,
        "csrf bypass" => /\bskip_forgery_protection\b/,
        "csrf null_session" => /\bprotect_from_forgery\b.*\bwith:\s*:null_session\b|\bwith:\s*:null_session\b/,
        "unsafe HTML html_safe" => /\bhtml_safe\b/,
        "unsafe HTML raw(...)" => /\braw\s*\(/,
        "thread-local request state" => /\bThread\.current\b/,
        "ignored rescue nil" => /rescue\s+nil\b/,
        "cross-host redirect escape hatch" => /\ballow_other_host:\s*true\b/,
      }.freeze

      SECURITY_LOGGER_PATH_PATTERN =
        %r{\A(?:app|lib)/(?:controllers/concerns/(?:authentication|authorization_audit|oidc)|
                          services/(?:chronicle|jit/security)|
                          subscribers/jwt_anomaly_subscriber|
                          jit/security)}x

      # Allowlist entries document existing reviewed exceptions. They are not
      # blanket permission for new uses: the line snippet must still match.
      ALLOWLIST = [
        {
          pattern: "access policy bypass",
          path: "app/controllers/concerns/browser_rp_authentication.rb",
          line: /\A\s*raise SkipNotAllowedError, "skip_before_action :enforce_access_policy! is prohibited/,
          reason: "The Browser RP policy guard raises when an inheritor attempts to disable authorization.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/common_redirect.rb",
          line: /redirect_to\(result\.value, allow_other_host: true/,
          reason: "Only the Jump gateway facade enables cross-host redirects after validating the token URL.",
        },
        {
          pattern: "csrf bypass",
          path: "app/controllers/concerns/csp_violation_report.rb",
          line: /skip_forgery_protection\(only: :create\)/,
          reason: "CSP reports are sensor inputs; creation is rate limited and reads bounded bodies only.",
        },
      ].freeze

      LOGGER_ALLOWLIST = [].freeze

      RAW_ACTOR_CLAIMS_ALLOWLIST = [
        {
          path: "app/policies/application_policy.rb",
          line: /Actor\.authz\.token_claims/,
          reason: "ApplicationPolicy is the reviewed policy boundary for current raw authz claims.",
        },
      ].freeze

      test "allowlist entries have explicit reasons" do
        missing_reasons =
          (ALLOWLIST + LOGGER_ALLOWLIST + RAW_ACTOR_CLAIMS_ALLOWLIST).filter_map do |entry|
            "#{entry[:path]} #{entry[:pattern]}" if entry.fetch(:reason).blank?
          end

        assert_empty missing_reasons, "Forbidden-pattern allowlist entries require reasons"
      end

      test "production code does not introduce forbidden security patterns" do
        offenders =
          production_code_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              pattern_name = FORBIDDEN_PATTERNS.find { |_name, pattern| line.match?(pattern) }&.first
              next unless pattern_name
              next if allowlisted?(ALLOWLIST, pattern_name, relative_path, line)

              "#{relative_path}:#{line_number}: #{pattern_name}: #{line.strip}"
            end
          end

        assert_empty offenders, "Forbidden security patterns found:\n#{offenders.join("\n")}"
      end

      test "authentication audit and security code uses structured logger error calls" do
        offenders =
          production_code_paths.filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next unless relative_path.match?(SECURITY_LOGGER_PATH_PATTERN)

            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
            lines = content.lines
            lines.each_with_index.filter_map do |line, index|
              next unless line.match?(/\bRails\.logger\.error\b/)
              next if lines[index, 4].join.include?("JitLogEvent.format(")
              next if allowlisted?(LOGGER_ALLOWLIST, nil, relative_path, line)

              "#{relative_path}:#{index + 1}: direct Rails.logger.error: #{line.strip}"
            end
          end.flatten

        assert_empty offenders,
                     "Use Rails.logger.error(JitLogEvent.format(...)) or a sanitized audit sink instead:\n" \
                     "#{offenders.join("\n")}"
      end

      test "raw Actor token claims access stays inside reviewed boundaries" do
        raw_claims_pattern = /Actor\.(?:authn|authz)\.(?:access_claims|token_claims)\b/
        offenders =
          production_code_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(raw_claims_pattern)
              next if allowlisted?(RAW_ACTOR_CLAIMS_ALLOWLIST, nil, relative_path, line)

              "#{relative_path}:#{line_number}: raw Actor token claims access: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Use typed Actor readers or add an explicit reviewed boundary reason:\n" \
                     "#{offenders.join("\n")}"
      end

      private

      def production_code_paths
        Rails.root.glob("{app,lib}/**/*").select do |path|
          File.file?(path) &&
            path.extname.in?(%w(.rb .erb .rake)) &&
            path.to_s.exclude?("/app/assets/builds/")
        end
      end

      def allowlisted?(entries, pattern_name, path, line)
        entries.any? do |entry|
          (pattern_name.nil? || entry[:pattern] == pattern_name) &&
            entry.fetch(:path) == path &&
            line.match?(entry.fetch(:line))
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
