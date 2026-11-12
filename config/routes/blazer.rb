# typed: false
# frozen_string_literal: true

# Blazer owns the SQL exploration dashboard (Blazer::Engine), on its own dedicated host.
# Public canonical host: blazer-governance.umaxica.dev.
constraints host: ["blazer-governance.umaxica.dev"] do
  # `blazer` is a `group :development` gem (Gemfile); it is not in the test group's load path,
  # so the engine constant does not exist while running the test suite.
  if defined?(Blazer::Engine)
    # HTTP Basic Auth is applied as engine middleware in config/initializers/blazer.rb, not by
    # wrapping the engine in a Rack app here: a wrapped engine is no longer recognised as a Rails
    # app by `mount`, which then hands it a mount-relative PATH_INFO its own route set never
    # matches, so every request 404s past the engine. Mount it directly and keep the credential
    # check inside its own stack.
    mount Blazer::Engine => "/", :as => :blazer
  end
end
