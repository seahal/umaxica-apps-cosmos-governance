# frozen_string_literal: true

require "test_helper"

class IdentityAuthenticationEventUniquenessTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [
    [Client, AppIdentityAuthenticationEvent, "app", "idx_app_identity_authentication_events_event_id"],
    [Operator, OrgIdentityAuthenticationEvent, "org", "idx_org_identity_authentication_events_event_id"],
  ].each do |actor_class, event_class, realm, constraint|
    test "#{realm} identity event reserves its event ID across actor and epoch changes" do
      attributes = {
        event_id: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f8b41",
        actor_ref: "123",
        realm: realm,
        cutoff_epoch: 1,
        reason: "sign_risk",
        scope: "all_sessions",
        committed_at: Time.utc(2026, 11, 12),
      }
      original = event_class.create!(attributes)
      duplicate = event_class.new(attributes.merge(actor_ref: "456", cutoff_epoch: 2))

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:event_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }

      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          event_class.transaction(requires_new: true) { duplicate.save!(validate: false) }
        end
      assert_equal constraint, error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      assert_predicate original, :valid?
    ensure
      original&.delete
    end

    test "#{realm} identity stop records the owner database instant rather than the application clock" do
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      before_recording = event_class.database_now
      event = nil

      travel_to(Time.utc(2000, 1, 1)) do
        event = IdentityAuthenticationStopRecorder.call(actor: actor, reason: "sign_risk")
      end

      after_recording = event_class.database_now

      assert_operator event.reload.committed_at, :>=, before_recording
      assert_operator event.committed_at, :<=, after_recording
    ensure
      event&.delete
      actor&.delete
    end

    test "#{realm} event collision cannot retain an epoch increment when its caller rescues validation failure" do
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      event_id = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f8b42"
      original =
        SecureRandom.stub(:uuid, event_id) do
          IdentityAuthenticationStopRecorder.call(actor: actor, reason: "sign_risk")
        end
      original_epoch = actor.reload.authentication_epoch

      actor_class.transaction(requires_new: true) do
        SecureRandom.stub(:uuid, event_id) do
          assert_raises(ActiveRecord::RecordInvalid) do
            IdentityAuthenticationStopRecorder.call(actor: actor, reason: "sign_risk")
          end
        end
      end

      assert_equal original_epoch, actor.reload.authentication_epoch
      assert_equal 1, event_class.where(actor_ref: actor.id.to_s).count
      assert_equal original_epoch, original.reload.cutoff_epoch
    ensure
      event_class.where(actor_ref: actor.id.to_s).delete_all if actor
      actor&.delete
    end
  end
end
