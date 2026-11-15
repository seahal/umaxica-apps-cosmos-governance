# Coverage, Gitleaks and Owner-Deferred Database Items

Date: 2026-11-14 Repository: `umaxica-apps-cosmos-governance` Branch: `feature` HEAD:
`eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree contained 1,207 changed or untracked paths before this evidence file was added,
including substantial uncommitted work from earlier tasks. Results describe that combined tree. No
commit, push, CI change, credentials change, schema-source change, production/shared DB operation,
history rewrite, or suppression was made. The already-dirty `.github/workflows/ci.yml` was
preserved.

## Gitleaks current tree

The scan copied tracked and unignored current-tree files to a temporary snapshot and used the
generated default Gitleaks configuration, which has no allowlist. Values and environment contents
were not printed or retained.

| Check                                |             Before cleanup |            After cleanup | Final scan after Base App restoration |
| ------------------------------------ | -------------------------: | -----------------------: | ------------------------------------: |
| Default Gitleaks rules, no allowlist | 8,136 files / 118 findings | 8,136 files / 3 findings |                            3 findings |

The changes and dispositions were:

- The 107 values in `research/2026-10-22-test-value-audit/duplicates.md` are SHA-256 source-body
  digests, not credentials. Their label was corrected; the values were preserved exactly.
- Full commit IDs in
  `plans/archive/0003-authentication-handoff-work-logs/zero-agent-message-board.md` were shortened
  to unique 12-character prefixes. No Git history was rewritten.
- Six historical evidence matches were environment-assignment examples, not credentials. The
  assigned values were replaced with redaction markers in
  `evidence/2026-09-15-e0-test-environment.md:34`, `evidence/2026-09-17-otp-consumption-lock.md:33`,
  `evidence/2026-09-17-otp-resend-lock.md:27`, and
  `evidence/2026-09-18-jwt-anomaly-catalog-audit.md:53,56,62`.
- Two remaining workflow matches are reported by location only: `.github/workflows/ci.yml:392` and
  `.github/workflows/ci.yml:675`. `.github/` was not edited for this work.
- `compose.yaml:50` is a public container image reference that Gitleaks classifies as a generic API
  key. No credential is present; the image reference was retained.

No real credential was identified. The current-tree zero-finding goal remains unmet only by the two
out-of-scope workflow locations and the Compose image false positive. No Gitleaks allowlist,
suppression or exclusion was added.

## Coverage progress

The accepted spec remains `implementing` at
[`specs/test-coverage-completion/spec.md`](../specs/test-coverage-completion/spec.md). Coverage
behavior is exercised through application entry points; no private-method seam, threshold change,
exclusion, or coverage-ignore annotation was added.

| Metric   | Before this pass | Final coverage run | Minimum |
| -------- | ---------------: | -----------------: | ------: |
| Lines    |           90.55% |             90.56% |     98% |
| Branches |           62.31% |             62.12% |     93% |
| Methods  |           86.13% |             86.14% |     97% |

The Base App restoration added behavior coverage for the RP entry, callback, token exchange, session
commit, sign-out and BCL. The repository-wide caller search found no caller for
`OidcOpTokenClient.refresh`; that public class method was removed rather than tested through a
private seam. The final coverage run was **7,582 runs / 50,714 assertions / 7 failures / 0 errors /
0 skips**. The seven failures are the explicitly out-of-scope Base App step-up paths listed in
[`2026-11-14-base-app-sign-entry-restoration-BAS1.md`](2026-11-14-base-app-sign-entry-restoration-BAS1.md).
The measured thresholds remain unmet; no report claims otherwise.

For comparison, the last recorded green full behavior run before these additions was **7,516 runs /
50,265 assertions / 0 failures / 0 errors / 0 skips**. The current full suite includes 66 additional
tests. Full-run failures that appeared only with suite ordering were not reproduced by isolated
preference/CSRF/CSP and CSRF-notification tests; the isolated results were **46 / 1,215 / 0** and
**5 / 21 / 0**, respectively. Their full-suite instability remains unresolved.

The final test run changed migration-owned fixture constraint flags. Only three disposable test
databases were reconstructed using their own Rails drop/create/migrate tasks after confirming zero
other sessions. A read-only post-rebuild catalog check found **16 test writers / 79 NOT VALID FKs /
0 NOT VALID CHECKs**. The APP Setting, ORG Setting and Occurrence migration receipt counts were
**17**, **17**, and **118**. No tests ran after reconstruction. This does not establish historical
production/shared row validity or validation lock cost.

## Owner-deferred items left unchanged

| Item                                                                                      | Current status                                                                                                                                                                           | Owner options and risk                                                                                                                                                                                         |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted` DatabaseConsistency finding | Preserved the model validator and PostgreSQL partial expression unique index. The final check still reports exactly this one finding.                                                    | Accept and track the checker capability gap, or evaluate a checker version/implementation that recognizes the JSON-text expression contract. Weakening uniqueness risks duplicate event-18 audit identity.     |
| 79 `NOT VALID` foreign keys                                                               | No migration/schema source changed. The test databases were restored to the migration-owned count only.                                                                                  | Keep pending, or approve a staged validation after a read-only orphan inventory and environment-specific lock/load/recovery plan. Validation may fail on historical orphans and impose scan/lock cost.         |
| Chronicle event-18 identity gap                                                           | The current combined worktree already requires non-NULL JSON text identity fields with a validated CHECK; this task made no change. Production/shared row conformity remains unverified. | Keep the current contract or have the audit owner decide empty-string and JSON value-type semantics before tightening further. Inference or deletion risks damaging audit history; validation cost is unknown. |
| Herb adoption                                                                             | Existing decision remains queued until split cleanup is complete across the four repositories. No adoption change was made.                                                              | Honor the recorded queue or explicitly amend it if conditions materially change. Early adoption risks unverified ERB lint/render compatibility; the backlog says not to re-evaluate the decision now.          |

No owner decision was requested or made for these items. Current supporting records include
[`evidence/2026-11-13-owner-items-disposition-O7R4.md`](2026-11-13-owner-items-disposition-O7R4.md),
the database consistency spec and the Herb migration backlog.

## Verification and handling

- `gitleaks detect --no-git` against a tracked/unignored snapshot, default config, no allowlist:
  final result **3 findings** as classified above.
- Coverage-enabled `bin/rails test`: **7,582 / 50,714 / 7 failures / 0 errors / 0 skips**; SimpleCov
  **90.56% / 62.12% / 86.14%** against unchanged **98% / 93% / 97%** minimums.
- `bin/rubocop`: **2,860 files / 0 offenses** after formatting the restored Base App navigation.
- `bundle exec erb_lint --lint-all`: no ERB errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: zero warnings.
- `bun run check`, `bin/rails zeitwerk:check`, `bin/rails routes`, and `git diff --check`: passed.
- `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency`: exit 1, one known finding.

Earlier diagnostic output included a nonsecret test database preparation list and test-generated
signed-token values. They are not repeated here; no real credential or key material was accessed.
Temporary logs from this task are removed after evidence is recorded.

No commit or push was made.
