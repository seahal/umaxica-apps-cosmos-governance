# typed: false
# frozen_string_literal: true

# Durable ownership facts for an telephone binding. A candidate may
# share a destination with other candidates; only a finalized, unreleased row
# participates in identity lookup and cardinality.
# Requires contact_binding_digest, accessible? and self.class.database_now from the concrete model.
module TelephoneContactBinding
  extend ActiveSupport::Concern

  public

  def binding_effective?
    binding_finalized_at.present? && binding_released_at.blank?
  end

  def binding_released?
    binding_released_at.present?
  end

  def release_binding!(at: self.class.database_now)
    raise ArgumentError, "candidate contact binding cannot be released" if binding_finalized_at.blank?
    return self if binding_released_at.present?

    update!(binding_released_at: at)
    self
  end

  def retire_for_withdrawal!
    owner, status_column, suspended =
      case self
      when ClientTelephone then [Client.find(user_id), :user_telephone_status_id, ClientTelephoneStatus::SUSPENDED]
      else raise ArgumentError, "unsupported withdrawal telephone"
      end
    owner.with_lock do
      raise ArgumentError, "telephone withdrawal owner is not terminated" unless owner.terminated?

      with_lock do
        now = self.class.database_now
        deadline = owner.purge_eligible_at
        unless deadline == Float::INFINITY || purge_eligible_at == Float::INFINITY
          deadline = [deadline, purge_eligible_at].max
        end
        discarded = [created_at, now].max
        deadline = [deadline, discarded].max unless deadline == Float::INFINITY
        update_attributes = { discard_at: discarded, purge_eligible_at: deadline }
        update_attributes[status_column] = suspended
        update!(update_attributes)
      end
    end
    self
  end

  private

  def effective_binding_has_digest
    return if binding_finalized_at.blank?
    return if contact_binding_digest.present?

    errors.add(:base, "an effective contact binding requires a destination digest")
  end
end
