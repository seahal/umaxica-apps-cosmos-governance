# frozen_string_literal: true

require "test_helper"
require "prism"

class RootTokenCreationInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ROOT_TOKEN_WRITES = %i(create create! insert insert! insert_all insert_all!).freeze
  ROOT_TOKEN_RECEIVERS = /\A(?:ClientToken|OperatorToken|token_class)\z/.freeze
  ROOT_TOKEN_ASSOCIATIONS = /\.(?:client_tokens|staff_tokens)\z/.freeze
  ROOT_TOKEN_TABLE_INSERTS = /\bINSERT\s+INTO\s+(?:client_tokens|operator_tokens)\b/i.freeze
  test "Base and Tech do not issue authority root tokens locally" do
    violations = []

    (Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")).each do |path|
      source = File.read(path)
      pending = [Prism.parse(source).value]

      until pending.empty?
        node = pending.pop

        if node.is_a?(Prism::CallNode) && ROOT_TOKEN_WRITES.include?(node.name)
          receiver = node.receiver&.location&.slice.to_s
          root_token_write = ROOT_TOKEN_RECEIVERS.match?(receiver) || ROOT_TOKEN_ASSOCIATIONS.match?(receiver)
          if root_token_write
            violations << "#{path.relative_path_from(Rails.root)}:#{node.location.start_line}"
          end
        elsif (node.is_a?(Prism::StringNode) || node.is_a?(Prism::InterpolatedStringNode)) &&
            ROOT_TOKEN_TABLE_INSERTS.match?(node.location.slice)
          violations << "#{path.relative_path_from(Rails.root)}:#{node.location.start_line}"
        end

        node.child_nodes.compact.each { |child| pending << child }
      end
    end

    assert_empty violations.uniq, "Authority root tokens are consumed by Base and Tech, not issued locally"
  end
end
