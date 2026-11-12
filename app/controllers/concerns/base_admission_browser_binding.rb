# typed: false
# frozen_string_literal: true

require "base64"

# Base keeps one random browser marker in its host-only Rails session while an
# admission crosses to Auth. The marker is never placed in a URL, form, page
# prop, cookie value, or log; only its per-entry digest reaches Ticket storage.
module BaseAdmissionBrowserBinding
  extend ActiveSupport::Concern

  include FrameDenyingContentSecurityPolicy

  BROWSER_NONCE_SESSION_KEY = "auth_admission_browser_nonce"
  BROWSER_NONCE_BYTES = 32

  public

  # Call only from a CSRF-protected Base initiation POST. Every initiation
  # issues a fresh marker: a value already in the session may have been planted
  # with a fixed session cookie, so it is never adopted as this browser's proof.
  def ensure_base_admission_browser_nonce!
    session[BROWSER_NONCE_SESSION_KEY] = Base64.urlsafe_encode64(
      SecureRandom.random_bytes(BROWSER_NONCE_BYTES), padding: false,
    )
  end
end
