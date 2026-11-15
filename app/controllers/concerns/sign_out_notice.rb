# typed: false
# frozen_string_literal: true

module SignOutNotice
  extend ActiveSupport::Concern

  SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
  SIGN_OUT_NOTICE_TTL = 5.minutes

  private

  def prepare_sign_out_notice!(state:, session_record:, actor_ref:, face:)
    expires_at = SIGN_OUT_NOTICE_TTL.from_now
    @prepared_sign_out_notice_id = SignOutNoticeStoreAdapter.new.issue!(
      payload: {
        actor_ref:,
        face:,
        sid: session_record.public_id,
        expires_at: expires_at.iso8601,
        state:,
      },
      ttl: SIGN_OUT_NOTICE_TTL,
    )
  end

  def attach_sign_out_notice_to_session!
    raise ArgumentError, "sign-out notice must be prepared before session reset" if @prepared_sign_out_notice_id.blank?

    session[SIGN_OUT_NOTICE_SESSION_KEY] = @prepared_sign_out_notice_id
  end

  def read_sign_out_notice(raw_id)
    SignOutNoticeStoreAdapter.new.read(raw_id: raw_id)
  end

  def consume_sign_out_notice(raw_id)
    SignOutNoticeStoreAdapter.new.consume(raw_id: raw_id)
  end

  def sign_out_notice_cache_headers!
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Referrer-Policy"] = (action_name == "edit") ? "strict-origin" : "no-referrer"
  end
end
