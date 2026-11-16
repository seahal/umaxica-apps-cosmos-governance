# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::SelectorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    [OperatorStatus, OperatorVisibility].each(&:ensure_defaults!)
    OperatorSecurityMode.insert_missing_fixed_ids!(OperatorSecurityMode::DEFAULTS)
    OperatorPasskeyStatus.find_or_create_by!(id: OperatorPasskeyStatus::ACTIVE)
    @operator = Operator.create!(
      security_mode_id: OperatorSecurityMode::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @operator = OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @external_session_ref = SecureRandom.uuid
  end

  test "unauthenticated operator cannot access selector" do
    get base_org_selector_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "one eligible ORG candidate is selected during the sign in flow" do
    headers = authenticated_headers
    candidate = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    get base_org_selector_url(host: @host, ri: "jp"), headers: headers

    assert_response :see_other
    assert_equal base_org_dashboard_path(ri: "jp"), URI(response.location).request_uri
    assert_equal candidate.account.public_id, rp_selection.fetch(:account_public_id)
    assert_equal @external_session_ref, rp_session.op_session_binding.sid
  end

  test "unselected RP session renders an ORG Inertia selector without writing a choice" do
    create_second_candidate!
    session = rp_session
    get base_org_selector_url(host: @host, ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_equal "base/org/selectors/show", inertia_component
    assert_equal 2, inertia_props.fetch("candidates").length
    assert inertia_page.fetch("clearHistory")
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_not RpBaseOrgSessionSelection.exists?(rp_session_id: session.id)
  end

  test "unselected RP session can choose an ORG candidate" do
    candidates = create_second_candidate!
    selected = candidates.first.fetch(:public)
    patch base_org_selector_url(host: @host), params: selected, headers: authenticated_headers, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_equal selected.except(:avatar_public_id).stringify_keys, rp_selection.slice(
      :account_public_id, :organization_public_id, :organization_unit_public_id,
    )
    assert_equal @external_session_ref, rp_session.op_session_binding.sid
  end

  test "selected RP session cannot overwrite its ORG choice through selector" do
    candidates = create_second_candidate!
    first = candidates.first.fetch(:public)
    second = candidates.last.fetch(:public)
    headers = authenticated_headers
    patch base_org_selector_url(host: @host), params: first, headers: headers, as: :json

    assert_response :success

    patch base_org_selector_url(host: @host), params: second, headers: headers, as: :json

    assert_response :conflict
    assert_equal "already_selected", response.parsed_body.fetch("status")
    assert_equal first.except(:avatar_public_id).stringify_keys, rp_selection.slice(
      :account_public_id, :organization_public_id, :organization_unit_public_id,
    )
  end

  test "selected RP session returns to the switcher from selector" do
    candidates = create_second_candidate!
    patch base_org_selector_url(host: @host),
          params: candidates.first.fetch(:public),
          headers: authenticated_headers,
          as: :json

    assert_response :success

    get base_org_selector_url(host: @host, ri: "jp"), headers: authenticated_headers

    assert_response :see_other
    assert_equal base_org_switcher_path(ri: "jp"), URI(response.location).request_uri
  end

  private

  def authenticated_headers
    @authenticated_headers ||= as_staff_headers(@operator, host: @host, session_public_id: @external_session_ref)
  end

  def rp_session
    authenticated_headers
    token_id = @external_session_ref
    session_public_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseOrgSession::CLIENT_ID, @operator.public_id,
       token_id,],
    )
    RpBaseOrgSession.includes(:op_session_binding).find_by!(public_id: session_public_id)
  end

  def rp_selection
    RpBaseOrgSessionSelection.find_by!(rp_session_id: rp_session.id).slice(
      :account_public_id, :organization_public_id, :organization_unit_public_id,
    )
  end

  def create_second_candidate!
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    config = AcmeSelector.config_for(:org)
    config.membership_kind_class.ensure_defaults!
    config.membership_state_class.ensure_defaults!
    unit = config.unit_class.create!(
      config.unit_collective_association => bootstrap.collective,
      :name => "Additional unit",
    )
    attributes = {
      membership_kind_id: config.membership_kind_class::MEMBER,
      membership_state_id: config.membership_state_class::ACTIVE,
      primary: false,
      metadata: {},
      starts_at: Time.current,
    }
    attributes[config.membership_account_association] = bootstrap.account
    attributes[config.membership_collective_association] = bootstrap.collective
    attributes[config.membership_unit_association] = unit
    config.membership_class.create!(**attributes)
    BaseSelectorAuthority.new(surface: :org, principal: @operator, session: rp_session).selectable_candidates
  end
end
