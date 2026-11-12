# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Email::SurfaceMailersTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "alert mailers send a generic alert payload per surface" do
    [
      [Email::App::AlertMailer, "alert@umaxica.app"],
      [Email::Org::AlertMailer, "alert@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(email_address: "target@example.com", title: "Alert title", body: "Alert body").notice

      assert_equal "Alert title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Alert body", mail.text_part.body.decoded
    end
  end

  test "promotional mailers send from promotional addresses per surface" do
    [
      [Email::App::PromotionalMailer, "promotion@umaxica.app"],
      [Email::Org::PromotionalMailer, "promotion@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Promotion body", mail.text_part.body.decoded
      assert_match "https://example.com/campaign", mail.text_part.body.decoded
    end
  end

  test "promotional mailers omit unsafe cta urls" do
    [
      Email::App::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "javascript:alert(1)",
      ).notice

      assert_match "Promotion body", mail.text_part.body.decoded
      assert_not_includes mail.text_part.body.decoded, "javascript:alert"
      assert_not_includes mail.html_part.body.decoded, "javascript:alert"
    end
  end

  test "promotional mailers omit cta urls with credentials" do
    [
      Email::App::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://user:pass@example.com/campaign",
      ).notice

      assert_not_includes mail.text_part.body.decoded, "user:pass"
      assert_not_includes mail.html_part.body.decoded, "user:pass"
    end
  end

  test "promotional mailers can set unsubscribe headers per surface" do
    [
      [Email::App::PromotionalMailer, ClientEmail.new(public_id: "app-email-public-id"), "promotion@umaxica.app"],
      [Email::Org::PromotionalMailer, OperatorEmail.new(public_id: "org-email-public-id"), "promotion@umaxica.org"],
    ].each do |mailer, email_record, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
        email_record: email_record,
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal [sender], mail.from
      assert_match "List-Unsubscribe", mail.header.to_s
    end
  end

  private

  def encrypted_otp(code)
    OutboundSensitivePayload.encrypt_email_otp(code)
  end
end
