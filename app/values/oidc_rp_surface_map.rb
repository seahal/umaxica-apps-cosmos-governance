# typed: false
# frozen_string_literal: true

# Current browser RP and callback map for Base and Tech.
module OidcRpSurfaceMap
  module_function

  FIRST_PARTY_RP_CLIENT_IDS = %w(base-app-ww base-org-ww tech-org-ww).freeze

  BASE_SELF_RP_CLIENT_IDS = %w(base-app-ww base-org-ww).freeze

  RP_FACES = {
    "base-app-ww" => { surface: "base", face: "app", actor: "client" },
    "base-org-ww" => { surface: "base", face: "org", actor: "operator" },
    "tech-org-ww" => { surface: "tech", face: "org", actor: "operator" },
  }.freeze

  CANONICAL_RP_CALLBACK_PATH = "/oidc/callback"
  BASE_STEP_UP_CALLBACK_PATHS = {
    "base-app-ww" => "/verification/oidc/callback",
    "base-org-ww" => "/verification/oidc/callback",
  }.freeze
  CANONICAL_RP_SIGN_IN_PATH = "/sign"
  CANONICAL_RP_SIGN_OUT_PATH = "/sign/out/completion"

  def first_party_rp_client_ids
    FIRST_PARTY_RP_CLIENT_IDS
  end

  def base_self_rp_client_ids
    BASE_SELF_RP_CLIENT_IDS
  end

  def rp_faces
    RP_FACES
  end

  def unique_client_ids?
    FIRST_PARTY_RP_CLIENT_IDS.uniq.size == FIRST_PARTY_RP_CLIENT_IDS.size
  end

  def callback_path_for(_client_id)
    CANONICAL_RP_CALLBACK_PATH
  end

  def step_up_callback_path_for(client_id)
    BASE_STEP_UP_CALLBACK_PATHS.fetch(client_id.to_s) do
      raise KeyError, "no registered Base step-up callback for #{client_id.inspect}"
    end
  end

  def sign_out_path_for(_client_id)
    CANONICAL_RP_SIGN_OUT_PATH
  end
end
