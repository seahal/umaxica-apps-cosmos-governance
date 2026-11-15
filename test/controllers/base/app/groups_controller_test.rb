# frozen_string_literal: true

require "test_helper"

class Base::App::GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "unauthenticated group reads redirect to neutral sign before owner access" do
    get base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :see_other
    assert_equal "/sign", URI.parse(response.location).path
  end

  test "authenticated group reads use Governance Avatar authority without changing group records" do
    group = GroupManagement::Create.call(
      account_surface: "app", account_public_id: @bootstrap.account.public_id,
      owner_surface: "app", owner_collective_public_id: @bootstrap.collective.public_id,
      actor: @user, subject_public_id: @bootstrap.account.public_id, name: "Existing",
    )
    original = group.attributes
    headers = selected_user_headers

    get base_app_groups_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes inertia_props.fetch("groups").map { |item| item.fetch("public_id") }, group.public_id
    get base_app_group_url(group.public_id, ri: "jp", host: @host), headers: headers

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal original, group.reload.attributes
  end

  test "group creation without CSRF proof is refused before changing Avatar records" do
    ActionController::Base.allow_forgery_protection = true
    headers = selected_user_headers

    assert_no_difference -> { AvatarGroup.count } do
      post base_app_groups_url(ri: "jp", host: @host), params: { group: { name: "Refused" } }, headers: headers
    end
    assert_response :unprocessable_content
    assert_equal 0, AvatarGroup.where(name: "Refused").count
  end

  test "group update and archival without CSRF proof preserve existing data" do
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: @bootstrap.account.public_id, name: "Existing", state: "active",
    )
    original = group.attributes
    ActionController::Base.allow_forgery_protection = true
    headers = selected_user_headers

    patch base_app_group_url(group.public_id, ri: "jp", host: @host),
          params: { group: { name: "Refused" } }, headers: headers

    assert_response :unprocessable_content
    assert_equal original, group.reload.attributes
    delete base_app_group_url(group.public_id, ri: "jp", host: @host), headers: headers

    assert_response :unprocessable_content
    assert_equal original, group.reload.attributes
  end

  test "membership writes without CSRF proof are refused without mutation" do
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: @bootstrap.account.public_id, name: "Existing", state: "active",
    )
    membership = GroupAvatarMembership.create!(
      avatar_group: group, avatar: @bootstrap.avatar, role: "member", position: 1, state: "active",
    )
    original = membership.attributes
    ActionController::Base.allow_forgery_protection = true
    headers = selected_user_headers

    assert_no_difference -> { GroupAvatarMembership.count } do
      post base_app_group_avatar_memberships_url(group.public_id, ri: "jp", host: @host),
           params: { membership: { avatar_public_id: @bootstrap.avatar.public_id, role: "owner", position: 2 } },
           headers: headers
    end
    assert_response :unprocessable_content
    patch base_app_group_avatar_membership_url(group.public_id, membership.public_id, ri: "jp", host: @host),
          params: { membership: { position: 4 } }, headers: headers

    assert_response :unprocessable_content
    assert_equal original, membership.reload.attributes
    delete base_app_group_avatar_membership_url(group.public_id, membership.public_id, ri: "jp", host: @host),
           headers: headers

    assert_response :unprocessable_content
    assert_equal original, membership.reload.attributes
  end

  test "group account-management scope accepts app and org" do
    assert_predicate AvatarGroup.new(account_surface: "app", account_public_id: "a", name: "App", state: "active"),
                     :valid?
    assert_predicate AvatarGroup.new(account_surface: "org", account_public_id: "o", name: "Org", state: "active"),
                     :valid?
  end

  private

  def selected_user_headers
    headers = as_user_headers(@user, host: @host, select_available_app_persona: false)
    session_id = Rack::Utils.parse_cookies_header(headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    session = RpBaseAppSession.find_by!(public_id: session_id)
    selection = BaseSelectorAuthority.select(
      surface: :app, principal: @user, session:,
      params: {
        account_public_id: @bootstrap.account.public_id,
        organization_public_id: @bootstrap.collective.public_id,
        organization_unit_public_id: @bootstrap.unit.public_id,
        avatar_public_id: @bootstrap.avatar.public_id,
      },
    )

    assert_equal "selected", selection.fetch(:status)

    assert_predicate session.reload, :selected_actor_context?

    headers
  end
end
