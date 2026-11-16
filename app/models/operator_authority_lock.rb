# typed: false
# frozen_string_literal: true

# Surface-local serialization row for org authority quota and ownership writes.
class OperatorAuthorityLock < OrgRpRecord
  belongs_to :operator, inverse_of: :authority_lock

  validates :operator_id, uniqueness: true, if: :will_save_change_to_operator_id?

  class << self
    public

    def acquire_for!(operator_id:)
      create_or_find_by!(operator_id:)
      lock.find_by!(operator_id:)
    rescue ActiveRecord::RecordInvalid => e
      # A competing insert may become visible during uniqueness validation before PostgreSQL
      # raises RecordNotUnique. Recover only that exact owner collision, never other failures.
      unless e.record.is_a?(OperatorAuthorityLock) &&
          e.record.errors.attribute_names == [:operator_id] &&
          e.record.errors.count == 1 && e.record.errors.of_kind?(:operator_id, :taken)
        raise
      end

      lock.find_by!(operator_id:)
    end
  end
end
