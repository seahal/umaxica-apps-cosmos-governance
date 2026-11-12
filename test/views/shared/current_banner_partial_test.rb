# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CurrentBannerPartialTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :operator_banners, :clients, :client_statuses, :operators,
           :operator_statuses

  test "renders the current banner for a surface" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :global, domain: :acme }

      assert_includes rendered, "Client newer banner"
      assert_includes rendered, "Client newer banner body"
    end
  end

  test "raises error when mandatory arguments are missing" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app } # region and domain are missing
    end
  end

  test "raises error when invalid tld is provided" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :net, region: :jp, domain: :acme }
    end
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: nil, region: :jp, domain: :acme }
    end
  end

  test "raises error when invalid domain is provided" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :jp, domain: :unsupported }
    end
  end

  test "raises error when invalid region is provided" do
    # 'nk' or nil are always invalid
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :nk, domain: :acme }
    end
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: nil, domain: :acme }
    end
  end

  test "raises error when invalid region for the Base domain is provided" do
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :jp, domain: :acme }
    end
    assert_raises ActionView::Template::Error do
      render partial: "layouts/shared/current_banner", locals: { tld: :org, region: :www, domain: :acme }
    end
  end

  test "renders nothing when the current banner is missing" do
    ClientBanner.stub(:current, ClientBanner.none) do
      render partial: "layouts/shared/current_banner", locals: { tld: :app, region: :global, domain: :acme }

      assert_empty rendered.strip
    end
  end
end
