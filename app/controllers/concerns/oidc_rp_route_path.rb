# typed: false
# frozen_string_literal: true

# Route helpers may include default query parameters from the current request. RP protocol
# registrations own the path; request context must not become part of that comparison.
module OidcRpRoutePath
  extend ActiveSupport::Concern

  private

  def rp_local_route_path(route)
    uri = URI.parse(route.to_s)
    valid = uri.relative? && uri.host.nil? && uri.userinfo.nil? && uri.path.start_with?("/") &&
      uri.fragment.nil?
    raise ActionController::BadRequest, "RP route must be a local absolute path" unless valid

    uri.path
  rescue URI::InvalidURIError
    raise ActionController::BadRequest, "RP route is invalid"
  end
end
