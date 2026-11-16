# typed: false
# frozen_string_literal: true

# Rejects cross-site or unverified unsafe Browser RP requests before surface callbacks run.
module BrowserRpUnsafeRequestGuard
  extend ActiveSupport::Concern

  public

  def guard_browser_rp_unsafe_request!
    return if request.get? || request.head? || request.options?

    browser_rp_request_safe_for_unsafe_method?
  end

  private

  def browser_rp_request_safe_for_unsafe_method?
    unless browser_rp_fetch_metadata_allowed? && browser_rp_origin_allowed?
      render_browser_rp_unsafe_request_rejected!
      return false
    end
    return true if verified_request_for_forgery_protection?

    render_browser_rp_unsafe_request_rejected!
    false
  end

  def render_browser_rp_unsafe_request_rejected!
    response.set_header("Cache-Control", "no-store")
    render plain: t("errors.messages.invalid_browser_request"), status: :unprocessable_content,
           content_type: "text/plain"
  end

  def browser_rp_fetch_metadata_allowed?
    fetch_site = request.headers["Sec-Fetch-Site"].to_s.downcase
    return true if fetch_site.blank?

    %w(same-origin same-site).include?(fetch_site)
  end

  def browser_rp_origin_allowed?
    origin = request.origin.to_s
    return false if origin == "null"
    return true if origin.blank?
    return true if origin == request.base_url

    browser_rp_trusted_origins.include?(origin)
  end
end
