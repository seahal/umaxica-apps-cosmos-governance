# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundEmailSuspensionInterceptorTest < ActionMailer::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Flipper.disable(:outbound_email_suspended)
    Flipper.disable(:outbound_promotional_email_suspended)
  end

  test "transactional mail is delivered while no channel is suspended" do
    transactional_mail.deliver_now

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "suspending the email channel stops transactional mail" do
    Flipper.enable(:outbound_email_suspended)

    transactional_mail.deliver_now

    assert_empty ActionMailer::Base.deliveries
  end

  test "suspending promotional email stops promotional mail" do
    Flipper.enable(:outbound_promotional_email_suspended)

    promotional_mail.deliver_now

    assert_empty ActionMailer::Base.deliveries
  end

  test "suspending promotional email leaves transactional mail delivering" do
    Flipper.enable(:outbound_promotional_email_suspended)

    transactional_mail.deliver_now

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "suspending the email channel also stops promotional mail" do
    Flipper.enable(:outbound_email_suspended)

    promotional_mail.deliver_now

    assert_empty ActionMailer::Base.deliveries
  end

  private

  def transactional_mail
    Email::App::AlertMailer.with(
      title: "Account update",
      body: "Security setting changed",
      email_address: "user@example.com",
    ).notice
  end

  def promotional_mail
    Email::App::PromotionalMailer.with(
      title: "Release notes",
      body: "Body",
      email_address: "user@example.com",
    ).notice
  end
end
