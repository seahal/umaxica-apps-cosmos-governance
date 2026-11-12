# HTTP Cache Policy for Rails Controllers

This is the implementation reference for `Cache-Control` on retained Base and Tech controller
responses. The decision and reasoning are in
[`adr/global-and-publishing-default-no-store-policy.md`](../../adr/global-and-publishing-default-no-store-policy.md).
Static and fingerprinted assets served by Propshaft or Vite are outside it. Mounted operator tools
own their response policy.

## Default

Every Base app/com/org and Tech org application or bare controller root, and every standalone Base
API controller root, uses `DefaultNoStore`. Surface controllers inherit the root policy and do not
repeat it.

1. Declare the concern and callback once at the root:

   ```ruby
   include ::DefaultNoStore
   prepend_before_action :apply_default_no_store
   ```

2. `apply_default_no_store` is the first `before_action` on the root. The FQDN availability gate is
   first after it. A subclass that re-prepends callbacks calls `ensure_fqdn_gate_first!` to restore
   that order.
3. An action that needs caching opts in with `fresh_when`, `stale?`, `expires_in`, `expires_now`, or
   `http_cache_forever`.
4. `skip_before_action :apply_default_no_store` is forbidden.
5. New code does not opt into caching by directly writing `Cache-Control`; Rails commits the default
   after the action. A protocol-specific, stricter `no-store` response remains harmless.
6. A response that varies by the signed-in subject never opts into `public`.

`test/security/invariants/default_no_store_policy_invariant_test.rb` enforces the root declarations,
callback order, and prohibition on skipping the policy. Some framework controllers and mounted
engines are separate roots and own their own policies.

## Explicit cacheable actions

| Action                                      | Contract                                                   |
| ------------------------------------------- | ---------------------------------------------------------- |
| Base app/org dashboard avatar images       | `stale?` with an ETag and private caching                  |
| Base app/org `/.well-known/jwks.json`       | `expires_in 1.hour, public: true`                          |
| Base app/com/org sitemap responses          | `expires_in 5.minutes, public: true`, `s-maxage=600`       |

Health and revision endpoints, jump-return verification, Base org IAM and support pages, and
responses containing actor-specific state remain `no-store` unless a retained action has an
explicit owner-approved contract. The no-store invariant tests cover action order and local root
ownership; this table records only the current cache opt-ins.
