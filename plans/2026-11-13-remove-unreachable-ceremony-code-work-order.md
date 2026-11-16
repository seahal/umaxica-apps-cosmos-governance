Task (umaxica-apps-cosmos-governance only): remove application code that no application caller
reaches and that belongs to ceremonies Governance no longer runs. Unattended run: do not ask
questions; record items that need the owner and continue. Never print secrets or environment values.
Never edit config/credentials/*.yml.enc. No push, no deploy, no change outside this repository.

## Decision

Owner, 2026-11-13: remove it. Basis: Access is the OpenID Provider and runs every authentication
ceremony (sign-in, sign-up, step-up, WebAuthn, social callbacks); Governance owns identity data and
credential records but runs no ceremony
(`../umaxica-apps-cosmos-access/adr/ access-is-a-pure-openid-provider.md`, decisions 14 and 17 to
19, read-only). Code kept "in case" is not kept (`generic/no-compatibility-layer.mdc`).

Starting list, from `evidence/2026-11-12-coverage-completion-C8N4.md` ("Latest public-method audit
batch"), each reported there as having no application includer, caller or consumer: `FlowSignIn`,
`FlowSignUp`, `OpaqueAdmissionStore`, `AuthAdmissionBinding` (`SignFlow` reads only its duration
constant), `RefreshTokenShared`, `OidcConnectionRecord`, the Step-Up grant/result decode APIs and
the Step-Up result issuer, and `CoreRpBridge#actor`, `#subject`, `#core?`.

## Work

1. Re-verify each item against the current tree before touching it: search `app`, `lib`, `config`,
   `db`, routes, jobs, initializers, views, front-end and metaprogrammed references (`constantize`,
   `const_get`, `send`, string class names in YAML or locale files). A reference only from tests is
   not a caller. Record the search and its result per item.
2. For each item with no caller: delete the class or module, its tests, fixtures, factories,
   locales, documents and diagrams that describe it as current, and anything that existed only to
   serve it (follow the chain: after each deletion re-check what became unreachable). A constant
   still read elsewhere (the `AuthAdmissionBinding` duration) moves to its reader's owner.
3. For each item that does have a caller: keep it, and record the caller with file and line.
4. Extend the search with the same method to other sign-in, sign-up, step-up, WebAuthn, TOTP,
   social-sign-in and OP-session code in Governance. List candidates in the evidence; delete only
   those with no caller and no data-ownership role. Models and tables that hold identity or
   credential **records** stay (Governance owns them) even when no ceremony runs here.
5. Database: do not drop tables or columns in this order. If a deleted class was the only reader of
   a table, list the table for a later migration decision.
6. Do not touch `.github` (read-only in the container) or the server-to-server revocation and lookup
   paths; those are redesigned under the front-channel handoff decision and are reported, not
   removed, here.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle exec erb_lint --lint-all, bundle
exec database_consistency, bun run check, then bin/rails test after a test database reset (baseline:
7,657 tests, 0 failures, `evidence/2026-11-12-coverage-completion-C8N4.md`; explain every
difference). Record in evidence/YYYY-MM-DD-remove-unreachable-ceremony-code-XXXX.md (full
`git rev-parse HEAD`; uncommitted changes affected results): per item the search, the decision and
the files removed; items kept with their callers; further candidates found; tables left without a
reader; coverage before and after; and confirmation that config/credentials files are unchanged.
