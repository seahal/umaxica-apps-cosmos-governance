# Governance PS256 Follow-up

Date: 2026-11-12 Repository: `umaxica-apps-cosmos-governance` HEAD:
`eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The worktree already contained substantial uncommitted changes when this work order began. No
existing changes were reset, stashed, or reverted. At evidence time, `git status --short` reported
107 changed or untracked paths; tests and checks therefore describe the combined worktree. No
commit, push, deployment, or external repository write was made.

## Outcome

Governance first-party JWTs now use PS256 with RSA keys of at least 3072 bits and one shared
repository signing key set/JWKS. Governance verifiers reject non-PS256 algorithms. The local keyset
installer generates RSA 3072 keys. Identity ceremony grant/result decoders bind the token surface to
the caller's issuer ID before deriving `iss`/`aud` from unverified claims. This preserves the
Auth/Base app and org boundary after the signing keys became shared; TOTP remains app-only.

No credential values or real key material were created, printed, or stored. No file under
`config/credentials/` changed (`git diff --name-only -- config/credentials` returned no paths).

## Acceptance trace

| Work-order requirement                                                                                                  | Implementation and evidence                                                                                                                                                                                                                                                          |
| ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Accept only RSA PS256 public keys, require 3072 bits, reject other algorithms                                           | `lib/jit_security_jwt_jwk.rb`, `lib/jit_security_jwt_key_material.rb`; `test/unit/jit/security/jwt/jwk_test.rb` covers 2048-bit refusal and 3072/4096-bit acceptance; negative token cases cover ES384, RS256, PS384, `none`, HMAC, and header mismatch.                             |
| Verify Access-issued first-party ID/access/logout tokens with strict issuer, audience, type, time, and signature checks | OIDC ID-token codec, RFC 9068 access-token profile, and OP access-token verifier changes; focused codec/negative/temporal tests passed. The local suite does not contact live Access.                                                                                                |
| Sign Governance JWTs using one repository key set and publish only RSA PS256 public keys                                | `lib/jit_security_jwt_registry.rb`, issuer/keyset builder, `lib/runtime_role.rb`, local installer, JWKS controller tests, issuer tests, and OIDC client assertion/ID-token tests.                                                                                                    |
| Migrate Jump RT signing and return verification to PS256                                                                | `app/values/security_jwt_jump_rt_token_codec.rb`, Jump issuer/keyring/return verifier and associated tests. The remote Jump gateway registration and live verification were not performed.                                                                                           |
| Preserve purpose and surface separation after consolidating keys                                                        | All six ceremony contracts and their grant/result decoders now validate issuer-ID-to-surface binding. The new guard covers both supported issuer namespaces and rejects unknown or mismatched surfaces; email and telephone decoder tests reproduce and reject cross-surface tokens. |
| Update current PS256 documentation while distinguishing external algorithms and history                                 | Active JWT/Jump runbooks, relevant ADR amendments, SRS, and RP target backlog text updated. Remaining ES384 references are inventoried below.                                                                                                                                        |

## TDD and verification

- Initial JWK/key-material tests were red: 15 runs, 32 assertions, 6 failures, 4 errors. After the
  RSA/PS256 implementation they were green: 15 runs, 43 assertions, no failures or errors.
- The first full-suite run exposed six stale or security-relevant failures after key sharing. Two
  ceremony tests demonstrated that an app token was accepted by an org decoder when the shared key
  was used. Updating those expectations first produced red (`expected ... but nothing was raised`).
  Surface binding then made them pass. The other failures were stale Jump fixture naming, key DER
  encoding, RSA-expanded cookie-size candidates, and removed EC-specific JWK test assumptions; their
  tests were updated without weakening the assertions.
- Focused regression run: 107 runs, 1,166 assertions, 0 failures, 0 errors, 0 skips.
- Full suite: `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBYOPT=-W0 RAILS_ENV=test bin/rails test` —
  7,673 runs, 51,620 assertions, 0 failures, 0 errors, 0 skips. The output included thread exception
  traces carrying `AccessOpDataUnavailableError` from concurrency tests; Minitest reported no failed
  tests. Those traces were not investigated as part of this JWT work.
- `bin/rails zeitwerk:check` — passed (`All is good!`).
- `bin/rubocop` — passed, 2,927 files inspected, no offenses.
- `bundle exec erb_lint --lint-all` — passed, 1,203 files linted, no ERB errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — passed, 0 errors and 0 security
  warnings.
- `bun run check` — passed formatting, lint, typecheck, dead-code and OpenAPI checks. Knip emitted
  one configuration hint for an excluded compiled CSS extension.
- `git diff --check` — passed.

## Owner provisioning and external verification

Before production use, the authorized Governance owner must provision these configuration names with
matching values:

- `AUTH_JWT_PRIVATE_KEYSET`: the active RSA 3072-or-larger PKCS#8 private key, in the documented
  JSON kid-to-Base64 format.
- `AUTH_JWT_PUBLIC_KEYSET`: matching public RSA PS256 JWKs, including any still-valid grace keys.
- `AUTH_JWT_ACTIVE_KID`: the active key identifier matching the private and public keysets.
- `AUTH_JWT_REVOKED_KIDS`: the shared revoked-kid list, when revocation is needed.

The credentials owner must also ensure the ENV/credentials source used by each deployed runtime has
the same cut-over. This work did not inspect or change credential values. Access's live JWKS and
sign-in/token verification, Jump gateway's PS256 registration and acceptance of Governance RTs, and
Jump gateway return-token JWKS compatibility remain unverified owner-side actions. No production
deployment or key provisioning occurred. AWS KMS signing remains deferred for Governance.

## Remaining `ES384` matches

`grep -rn ES384 app lib config docs adr openapi` returned only the following categories:

- ChainSeal's independent P-384 ECDSA protocol and rotation docs: `lib/chain_seal.rb`,
  `docs/security/chain_seal.md`, `docs/runbooks/chain-seal-key-rotation.md`, and its row in
  `docs/runbooks/README.md`. ChainSeal is not a JWT signer.
- DPoP's external proof algorithm contract: `docs/architecture/dpop.md`; DPoP is not a first-party
  signed JWT family in this migration.
- Historical or explicitly superseded text:
  `docs/backlog/2026-11-10-core-security-review-followups.md`,
  `adr/runtime-secret-isolation-deferred.md`, and the pre-amendment history in
  `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`.
- `adr/cosmos-signing-key-management.md` remains Proposed/on hold and explicitly says the later
  accepted PS256 ADR supersedes its ES384 decision. It was not rewritten as part of the cut-over.
- `docs/runbooks/jwt-key-rotation.md` mentions ES384 only to forbid overlap/fallback.

No ES384 application-JWT acceptance or signing path remains in the audited Governance
implementation. The command searched text under `app lib config docs adr openapi`; it did not
inspect deployment systems or other repositories.

## Remaining limits

The repository-side cut-over is locally verified. Acceptance of the new key by live Access and Jump
consumers is not locally verifiable and remains outstanding before production reliance. The observed
concurrency-test thread exception traces are also recorded above without attribution or remediation.
