# frozen_string_literal: true

# Queries the actual indexed digest while reporting a duplicate on its semantic contact field.
class ContactBindingUniquenessValidator < ActiveRecord::Validations::UniquenessValidator
  public

  def self.kind
    :uniqueness
  end
  public_class_method :kind

  def validate_each(record, attribute, value)
    previous_count = record.errors.objects.length
    super
    added_error = record.errors.objects[previous_count]
    return unless added_error&.attribute == attribute && added_error.type == :taken

    record.errors.objects.delete_at(previous_count)
    record.errors.add(options.fetch(:error_attribute), :taken)
  end
end
