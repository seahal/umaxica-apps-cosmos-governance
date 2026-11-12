# typed: false
# frozen_string_literal: true

# A surface-local serialization row for quota and ownership writes.
#
# Client and the app RP/resource models have different semantic Active Record
# bases but inherit the same app_zenith writer boundary. The row is therefore
# the explicit lock target used by authority operations; it is not an authority
# grant and never answers an authorization question.
class ClientAuthorityLock < AppRpRecord
  belongs_to :client, inverse_of: :authority_lock

  validates :client_id, uniqueness: true, if: :will_save_change_to_client_id?

  class << self
    public

    def acquire_for!(client_id:)
      # Pass only the unique key. `create_or_find_by!` re-queries with every
      # supplied attribute after a unique violation; timestamps would make an
      # existing lock row impossible to find on the second acquisition.
      create_or_find_by!(client_id:)
      lock.find_by!(client_id:)
    rescue ActiveRecord::RecordInvalid => e
      # A competing insert may become visible during uniqueness validation before PostgreSQL
      # raises RecordNotUnique. Recover only that exact owner collision, never other failures.
      unless e.record.is_a?(ClientAuthorityLock) &&
          e.record.errors.attribute_names == [:client_id] &&
          e.record.errors.count == 1 && e.record.errors.of_kind?(:client_id, :taken)
        raise
      end

      lock.find_by!(client_id:)
    end
  end
end
