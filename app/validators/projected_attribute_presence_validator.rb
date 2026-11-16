# frozen_string_literal: true

# A required column omitted from a SELECT projection is not a NULL value.
# PostgreSQL remains responsible for rejecting NULL values on complete writes.
class ProjectedAttributePresenceValidator < ActiveModel::EachValidator
  def self.kind
    :presence
  end
  public_class_method :kind

  public
  def validate(record)
    return unless attributes.all? { |attribute| record.has_attribute?(attribute) }

    super
  end

  def validate_each(record, attribute, value)
    record.errors.add(attribute, :blank, **options) if value.blank?
  end
end
