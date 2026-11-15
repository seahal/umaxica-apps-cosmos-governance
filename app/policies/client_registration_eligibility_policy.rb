# typed: false
# frozen_string_literal: true

# Eligibility for an App registration start (adr/sign-up-one-day-minimum-age-and-feature-level-age-
# restrictions.md): a birthdate must be at least one calendar day before the service date of the
# check. Yesterday is the closest eligible date; today and later are refused.
class ClientRegistrationEligibilityPolicy
  BIRTHDATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  def self.birthdate_eligible?(birthdate, today:)
    return false unless birthdate.is_a?(String) && BIRTHDATE_FORMAT.match?(birthdate)

    Date.iso8601(birthdate) < today
  rescue Date::Error
    false
  end
  public_class_method :birthdate_eligible?
end
