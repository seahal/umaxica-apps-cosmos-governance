# typed: false
# frozen_string_literal: true

class AuthenticationSessionRevoker
  def self.revoke_all_for(_resource)
    raise AccessOpDataUnavailableError
  end
  public_class_method :revoke_all_for

  def self.tokens_for(_resource)
    raise AccessOpDataUnavailableError
  end
  public_class_method :tokens_for

  def self.tokens_for_method(_resource, _method)
    raise AccessOpDataUnavailableError
  end
  public_class_method :tokens_for_method
end
