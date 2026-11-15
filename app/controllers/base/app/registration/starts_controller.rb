# typed: false
# frozen_string_literal: true

module Base
  module App
    module Registration
      # H1 receiver: GET /registration/start?h=<registration-start+jwt>, reached through Jump from Auth.
      class StartsController < Base::App::BareController
        include ::CommonRedirect
        include ::ClientRegistrationHandoffReceiving

        HANDOFF_KIND = "start"
        ACCEPTED_METHODS = %w(email telephone).freeze
        IDENTIFIER_LIMIT = 10
        IDENTIFIER_WINDOW = 1.hour

        rate_limit to: 20, within: 1.minute, by: -> { request.remote_ip }, scope: "base_app_registration_start",
                   name: "registration_start", store: rate_limit_store,
                   with: -> { render_rate_limited(retry_after: 60) }

        public

        def show
          prepare_handoff_response!
          claims = verified_handoff_claims(HANDOFF_KIND)
          return unless claims
          # Google and Apple stay closed until the H1 contract carries the provider audience.
          return refuse_handoff!(:service_unavailable, HANDOFF_KIND, "method_unavailable") unless
            ACCEPTED_METHODS.include?(claims.fetch("mth"))

          secret = SecureRandom.urlsafe_base64(BROWSER_SECRET_BYTES)
          committer = ClientRegistrationStartCommitter.new(
            claims:, browser_secret_digest: presented_browser_secret_digest,
            new_browser_secret_digest: Digest::SHA256.hexdigest(secret),
          )
          return render_rate_limited(retry_after: IDENTIFIER_WINDOW.to_i) if identifier_limit_reached?(committer)

          result = committer.call!
          return answer_replay!(HANDOFF_KIND, claims) if result.replay?

          install_registration_cookie!(secret, result.registration) if %w(started completed).include?(result.reason)
          deliver_answer!(result, HANDOFF_KIND, claims)
        rescue ClientRegistrationStartCommitter::MalformedIdentifier
          refuse_handoff!(:bad_request, HANDOFF_KIND, "invalid_identifier")
        end

        private

        # Counted after verification so that unsigned junk cannot exhaust a person's identifier.
        def identifier_limit_reached?(committer)
          key = "base_app_registration_identifier:#{committer.identifier_bucket}"
          count = rate_limit_store.increment(key, 1, expires_in: IDENTIFIER_WINDOW)
          count.is_a?(Integer) && count > IDENTIFIER_LIMIT
        end
      end
    end
  end
end
