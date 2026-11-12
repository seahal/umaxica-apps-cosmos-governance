# frozen_string_literal: true

require "test_helper"

class Base::App::GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
  end

  test "unauthenticated group reads remain unauthorized before owner access" do
    get base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :unauthorized
    assert_nil response.location
  end

  test "authenticated group reads report missing Access authority without changing Avatar records" do
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: @bootstrap.account.public_id, name: "Existing", state: "active",
    )
    original = group.attributes
    headers = as_user_headers(@user, host: @host)

    get base_app_groups_url(ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    get base_app_group_url(group.public_id, ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, group.reload.attributes
  end

  test "group creation cannot substitute local RP authentication for absent owner authority" do
    headers = as_user_headers(@user, host: @host)

    assert_no_difference -> { AvatarGroup.count } do
      post base_app_groups_url(ri: "jp", host: @host), params: { group: { name: "Refused" } }, headers: headers
    end
    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "group update and archival preserve existing data when Access authority is unavailable" do
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: @bootstrap.account.public_id, name: "Existing", state: "active",
    )
    original = group.attributes
    headers = as_user_headers(@user, host: @host)

    patch base_app_group_url(group.public_id, ri: "jp", host: @host),
          params: { group: { name: "Refused" } }, headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, group.reload.attributes
    delete base_app_group_url(group.public_id, ri: "jp", host: @host), headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, group.reload.attributes
  end

  test "membership creation reordering and removal refuse missing authority without mutation" do
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: @bootstrap.account.public_id, name: "Existing", state: "active",
    )
    membership = GroupAvatarMembership.create!(
      avatar_group: group, avatar: @bootstrap.avatar, role: "member", position: 1, state: "active",
    )
    original = membership.attributes
    headers = as_user_headers(@user, host: @host)

    assert_no_difference -> { GroupAvatarMembership.count } do
      post base_app_group_avatar_memberships_url(group.public_id, ri: "jp", host: @host),
           params: { membership: { avatar_public_id: @bootstrap.avatar.public_id, role: "owner", position: 2 } },
           headers: headers
    end
    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    patch base_app_group_avatar_membership_url(group.public_id, membership.public_id, ri: "jp", host: @host),
          params: { membership: { position: 4 } }, headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, membership.reload.attributes
    delete base_app_group_avatar_membership_url(group.public_id, membership.public_id, ri: "jp", host: @host),
           headers: headers

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, membership.reload.attributes
  end

  test "group account-management scope accepts app and org" do
    assert_predicate AvatarGroup.new(account_surface: "app", account_public_id: "a", name: "App", state: "active"),
                     :valid?
    assert_predicate AvatarGroup.new(account_surface: "org", account_public_id: "o", name: "Org", state: "active"),
                     :valid?
  end
end
