# Governance PS256 Follow-up: Current-Tree Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree contained 1,012 changed or untracked paths. This revalidation made no
application, test, schema, CI, or credential edits. No commit, push, deployment, or external write
was made. The existing `.github/workflows/ci.yml` modification predates this revalidation and was
left untouched. `git status --short -- config/credentials` and
`git diff --name-only -- config/credentials` returned no paths.

## Current-tree verification

| Command                                                                                                                                                                                                     | Result                                                     |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `rg --files test -g '*_test.rb' \| rg '(jwt\|jump_rt\|jwks\|oidc.*(access\|jwks))' \| xargs env -u COVERAGE POSTGRESQL_TEST_PREPARE_DATABASES=<isolated test-writer catalog> RAILS_ENV=test bin/rails test` | 413 runs, 1,332 assertions, 0 failures, 0 errors, 0 skips. |
| `git rev-parse HEAD`                                                                                                                                                                                        | `eedf4f51e1e10517ac77381f6a1a03b58b984e71`                 |
| Credential path status/diff checks                                                                                                                                                                          | No changed paths.                                          |

The test selection covered current JWT/JWK key material and registry validation, public JWKS
endpoints, Access access-token verification, and Jump RT issuance and return verification. It passed
against the current worktree. The focused run used only the configured test writer catalog; no
production or shared database was prepared or changed.

The earlier implementation and full-check record is
[`2026-11-13-ps256-follow-up-G8M4.md`](2026-11-13-ps256-follow-up-G8M4.md). It records the
repository-side PS256 cut-over, the direct accepted/rejected token cases, static checks and key
source requirements. The latest full coverage-enabled Rails run is recorded in
[`2026-11-13-coverage-reachability-L6N2.md`](2026-11-13-coverage-reachability-L6N2.md): all 7,499
tests passed, while the process returned 2 because repository SimpleCov minima were not met.

## Owner provisioning and external checks

The deployment owner must provision compatible RSA PKCS#8 key material for
`AUTH_JWT_PRIVATE_KEYSET`, `AUTH_JWT_PUBLIC_KEYSET`, and `AUTH_JWT_ACTIVE_KID`, and coordinate
`AUTH_JWT_REVOKED_KIDS`. No real key material or environment values were inspected, created,
printed, or changed.

Live Access JWKS/sign-in, production key provisioning, and Jump gateway PS256 publication and
compatibility remain unverified external owner checks. No alternate signing algorithm or fallback
was introduced. Existing historical and external-protocol `ES384` references remain classified in
G8M4; this revalidation did not edit those records.
