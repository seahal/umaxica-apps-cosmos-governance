# frozen_string_literal: true

require "test_helper"

class BaseSwitcherAuthorityTest < ActiveSupport::TestCase
  test "post-cutover candidate resolution uses concrete Avatar ownership" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)

    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      avatars = BaseSwitcherAuthority.new(surface: :app, principal: actor).available_avatars

      assert_includes avatars.map(&:id), bootstrap.avatar.id
      assert_instance_of AvatarEnterpriseOwnershipPeriod, bootstrap.avatar.current_ownership_period

      authority = BaseSwitcherAuthority.new(surface: :app, principal: actor)
      accounts = authority.available_accounts
      organizations = authority.available_organizations
      candidate = authority.selectable_candidates.first
      selection_authority = BaseSwitcherAuthority.new(
        surface: :app, principal: actor, selection: candidate.fetch(:public),
      )

      assert_includes accounts.map(&:id), bootstrap.account.id
      assert_includes organizations.map(&:id), bootstrap.collective.id
      assert_equal bootstrap.account, authority.find_account(bootstrap.account.public_id)
      assert_equal bootstrap.collective, authority.find_organization(bootstrap.collective.public_id)
      assert_equal bootstrap.avatar, authority.find_avatar(bootstrap.avatar.public_id)
      assert_equal bootstrap.avatar, selection_authority.selected_avatar
      assert_nil authority.find_account("")
      assert_nil authority.find_organization("")
      assert_nil authority.find_avatar("")

      # Roll back the marker and synthetic graph through the ordinary test transaction.
      raise ActiveRecord::Rollback
    end
  end
end
