# typed: false
# frozen_string_literal: true

# Commits local RP-session revocation for either Base realm. The OP binding is locked first so a
# concurrent RP callback or Back-Channel Logout cannot reopen the browser session.
module RpBaseSessionSignOut
  extend ActiveSupport::Concern

  public

  def revoke_for_sign_out!
    session_class = self.class
    record_class = session_class.connection_class_for_self
    binding_class = session_class.reflect_on_association(:op_session_binding).klass

    record_class.connected_to(role: :writing) do
      record_class.transaction do
        binding = binding_class.lock.find(op_session_binding_id)
        lock!
        now = record_class.database_now
        next false if revoked_at.present? || binding.revoked_at.present? || absolute_expires_at <= now

        update!(revoked_at: now)
        true
      end
    end
  end
end
