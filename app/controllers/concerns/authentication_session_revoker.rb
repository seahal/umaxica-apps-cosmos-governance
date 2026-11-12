# typed: false
# frozen_string_literal: true

class AuthenticationSessionRevoker
  def self.revoke_all_for(_resource)
    raise AccessOpDataUnavailableError
  end

  def self.tokens_for(_resource)
    raise AccessOpDataUnavailableError
  end

  def self.tokens_for_method(_resource, _method)
    raise AccessOpDataUnavailableError
  end
end
