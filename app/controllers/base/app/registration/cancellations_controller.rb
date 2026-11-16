# typed: false
# frozen_string_literal: true

module Base
  module App
    module Registration
      # H5 receiver: GET /registration/cancellation?h=<registration-cancel+jwt>, reached through Jump.
      class CancellationsController < Base::App::BareController
        include ::CommonRedirect
        include ::ClientRegistrationHandoffReceiving

        HANDOFF_KIND = "cancellation"

        rate_limit to: 20, within: 1.minute, by: -> { request.remote_ip },
                   scope: "base_app_registration_cancellation", name: "registration_cancellation",
                   store: rate_limit_store, with: -> { render_rate_limited(retry_after: 60) }

        public

        def show
          prepare_handoff_response!
          claims = verified_handoff_claims(HANDOFF_KIND)
          return unless claims

          result = ClientRegistrationCancellationCommitter.call!(
            claims:, browser_secret_digest: presented_browser_secret_digest,
          )
          return answer_replay!(HANDOFF_KIND, claims) if result.replay?

          clear_registration_cookie! if result.reason == "cancelled"
          deliver_answer!(result, HANDOFF_KIND, claims)
        end
      end
    end
  end
end
