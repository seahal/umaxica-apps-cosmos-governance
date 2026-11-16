# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Governance owns the Base browser-RP and Tech operator surfaces.
  draw :base

  # Tech owns the global operator tools Browser RP.
  draw :tech

  # Repository-local diagnostic tools keep their exact host constraints and own Basic Auth.
  draw :mission
  draw :flipper
  draw :blazer
  draw :pghero
  draw :swagger
  draw :coverband

  # Any host that reached the app without matching a surface above is unknown;
  # answer it here rather than leaking a routing error.
  get "/", to: "unknown_hosts#show" # FIXIME: I want to remove this, or use root!
end
