# typed: false
# frozen_string_literal: true

module AuthIoKeys
  HOST_COOKIE_PREFIX = "__Host-"

  module Cookies
    ACCESS_BASENAME = "auth_access"
    REFRESH_BASENAME = "auth_refresh"

    public_constant :ACCESS_BASENAME
    public_constant :REFRESH_BASENAME
  end

  module Headers
    AUTHORIZATION = "Authorization"
    public_constant :AUTHORIZATION
  end

  module Params
    RI = :ri
    PT = :pt
    NT = :nt
    # Signed binding of a phase-bound request to the flow instance its page was rendered for.
    FLOW_BINDING = :fb

    public_constant :RI
    public_constant :PT
    public_constant :NT
    public_constant :FLOW_BINDING
  end

  module Session
    DEFAULT_PT = :user_email_authentication_pt
    CHECKPOINT = :sign_in_checkpoint
    BULLETIN = CHECKPOINT

    public_constant :DEFAULT_PT
    public_constant :CHECKPOINT
    public_constant :BULLETIN
  end

  module Env
    AUTH_REFRESHED_FLAG = "auth_refreshed"

    public_constant :AUTH_REFRESHED_FLAG
  end

  public_constant :HOST_COOKIE_PREFIX
end
