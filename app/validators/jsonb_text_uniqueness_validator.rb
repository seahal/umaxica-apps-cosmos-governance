# frozen_string_literal: true

# Checks the same JSON text values and row predicate used by a PostgreSQL expression index.
# The database index remains authoritative for concurrent inserts.
class JsonbTextUniquenessValidator < ActiveModel::EachValidator
  IDENTIFIER = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/
  private_constant :IDENTIFIER

  public

  def check_validity!
    raise ArgumentError, "JSON text uniqueness requires distinct simple keys" unless valid_keys?
    raise ArgumentError, "JSON text uniqueness requires a predicate hash" unless valid_predicate?
    raise ArgumentError, "JSON text uniqueness requires scalar predicate values" unless scalar_predicate_values?
    raise ArgumentError, "JSON text uniqueness requires simple column names" unless valid_identifiers?
  end

  def validate_each(record, attribute, value)
    return unless value.is_a?(Hash)

    predicate = options.fetch(:where)
    return unless predicate.all? do |column, expected|
      record.public_send(column) == record.class.type_for_attribute(column.to_s).cast(expected)
    end

    connection_owner = record.class.connection_class_for_self
    duplicate =
      connection_owner.connected_to(role: :writing) do
        connection_owner.connection_pool.with_connection do
          attribute_node = record.class.arel_table[attribute]
          serialized = value.to_json
          scope = record.class.unscoped.where(predicate)
          options.fetch(:keys).each do |key|
            quoted_key = Arel::Nodes.build_quoted(key)
            stored_text = Arel::Nodes::InfixOperation.new("->>", attribute_node, quoted_key)
            candidate = Arel.sql("CAST(? AS jsonb)", serialized)
            candidate_text = Arel::Nodes::InfixOperation.new("->>", candidate, quoted_key)
            scope = scope.where(stored_text.eq(candidate_text))
          end
          scope = scope.where.not(record.class.primary_key => record.id) if record.persisted?
          scope.exists?
        end
      end
    record.errors.add(attribute, :taken) if duplicate
  end

  private

  def valid_keys?
    keys = options.fetch(:keys)
    keys.is_a?(Array) && keys.present? && keys.uniq == keys &&
      keys.all? { |key| key.is_a?(String) && IDENTIFIER.match?(key) }
  end

  def valid_predicate?
    predicate = options.fetch(:where)
    predicate.is_a?(Hash) && predicate.present?
  end

  def scalar_predicate_values?
    options.fetch(:where).values.all? do |value|
      value.nil? || value.is_a?(String) || value.is_a?(Integer) || value == true || value == false
    end
  end

  def valid_identifiers?
    options.fetch(:where).keys.all? { |column| IDENTIFIER.match?(column.to_s) } &&
      attributes.all? { |attribute| IDENTIFIER.match?(attribute.to_s) }
  end
end
