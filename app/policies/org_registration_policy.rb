# typed: false
# frozen_string_literal: true

class OrgRegistrationPolicy
  class InvitationRequiredError < StandardError; end

  class InvalidInvitationError < StandardError; end

  class InvitationExpiredError < StandardError; end

  class InvitationConsumedError < StandardError; end

  def self.allowed?(invitation_code:, email: nil)
    new(invitation_code: invitation_code, email: email).allowed?
  end

  def self.validate!(invitation_code:, email: nil)
    raise AccessOpDataUnavailableError
  end

  def initialize(invitation_code:, email: nil)
    @invitation_code = invitation_code.to_s.downcase.strip
    @email = email.to_s.downcase.strip.presence
  end

  def allowed?
    raise AccessOpDataUnavailableError
  end

  def validate!
    raise AccessOpDataUnavailableError
  end

  def consume!
    raise AccessOpDataUnavailableError
  end
end
