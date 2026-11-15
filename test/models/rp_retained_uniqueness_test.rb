# frozen_string_literal: true

require "test_helper"

class RpRetainedUniquenessTest < ActiveSupport::TestCase
  test "Tech callback state digests remain reserved after consumption" do
    [RpTechOrgCallbackState].each do |model|
      attributes = {
        state_digest: Digest::SHA256.digest("unique-state"),
        browser_binding_digest: Digest::SHA256.digest("browser"),
        nonce_digest: Digest::SHA256.digest("nonce"),
        pkce_challenge: "challenge",
        pkce_verifier_ciphertext: "encrypted-verifier",
        issuer: "https://issuer.example",
        realm: model::REALM,
        client_id: model::CLIENT_ID,
        expires_at: Time.utc(2026, 11, 12, 12),
      }
      first = model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?, model.name
      assert duplicate.errors.of_kind?(:state_digest, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
      first.update!(consumed_at: first.expires_at - 1.minute)

      assert_predicate first.reload, :consumed?
      assert_not duplicate.valid?, model.name
      assert duplicate.errors.of_kind?(:state_digest, :taken)
      distinct = model.create!(attributes.merge(state_digest: Digest::SHA256.digest("different-state")))

      assert_not_equal first.id, distinct.id
      assert_not_predicate distinct, :consumed?
    end
  end

  [
    [RpBaseAppSessionSelection, RpBaseAppPrincipal, RpBaseAppIdentityBinding,
     RpBaseAppOpSessionBinding, RpBaseAppSession,],
    [RpBaseOrgSessionSelection, RpBaseOrgPrincipal, RpBaseOrgIdentityBinding,
     RpBaseOrgOpSessionBinding, RpBaseOrgSession,],
  ].each do |selection_model, principal_model, identity_model, binding_model, session_model|
    test "#{selection_model.name} permits one actor selection per session and updates the existing selection" do
      now = Time.utc(2026, 11, 12, 12)
      principal = principal_model.create!
      identity = identity_model.create!(
        principal: principal, issuer: "https://issuer.example", realm: session_model::REALM,
        client_id: session_model::CLIENT_ID, subject: "subject",
      )
      attributes = {
        account_public_id: "a" * 21,
        organization_public_id: "b" * 21,
        organization_unit_public_id: "c" * 21,
        selected_at: now,
      }
      attributes[:avatar_public_id] = "d" * 21 if selection_model == RpBaseAppSessionSelection
      sessions =
        %w(first second).map do |sid|
          binding = binding_model.create!(
            identity_binding: identity, issuer: identity.issuer, realm: identity.realm,
            client_id: identity.client_id, sid: sid,
          )
          session_model.create!(op_session_binding: binding, absolute_expires_at: now + 1.day)
        end
      first = selection_model.create!(attributes.merge(rp_session: sessions.first))
      duplicate = selection_model.new(attributes.merge(rp_session: sessions.first))

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:rp_session_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_raises(ActiveRecord::RecordNotUnique) do
        selection_model.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
      independent = selection_model.create!(attributes.merge(rp_session: sessions.last))
      first.update!(account_public_id: "z" * 21)

      assert_equal "z" * 21, first.reload.account_public_id
      assert_equal "a" * 21, independent.reload.account_public_id
      independent.rp_session = sessions.first

      assert_not independent.valid?
      assert independent.errors.of_kind?(:rp_session_id, :taken)
    end
  end

  test "ORG avatar selection has one row per actor selection while its avatar remains replaceable" do
    now = Time.utc(2026, 11, 12, 12)
    principal = RpBaseOrgPrincipal.create!
    identity = RpBaseOrgIdentityBinding.create!(
      principal: principal, issuer: "https://issuer.example", realm: RpBaseOrgSession::REALM,
      client_id: RpBaseOrgSession::CLIENT_ID, subject: "avatar-selection-subject",
    )
    binding = RpBaseOrgOpSessionBinding.create!(
      identity_binding: identity, issuer: identity.issuer, realm: identity.realm,
      client_id: identity.client_id, sid: "avatar-selection-session",
    )
    session = RpBaseOrgSession.create!(op_session_binding: binding, absolute_expires_at: now + 1.day)
    actor_selection = RpBaseOrgSessionSelection.create!(
      rp_session: session, account_public_id: "a" * 21, organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21, selected_at: now,
    )
    attributes = { actor_selection: actor_selection, avatar_public_id: "d" * 21, selected_at: now }
    first = RpBaseOrgSessionAvatarSelection.create!(attributes)
    duplicate = RpBaseOrgSessionAvatarSelection.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:rp_session_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      RpBaseOrgRecord.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    first.update!(avatar_public_id: "e" * 21)

    assert_equal "e" * 21, first.reload.avatar_public_id
    assert_equal 1, RpBaseOrgSessionAvatarSelection.where(rp_session_id: session.id).count
  end
end
