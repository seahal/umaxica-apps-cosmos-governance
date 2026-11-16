# Vitest and Minitest coverage completion

Status: implementing

Authority: owner request on 2026-11-12 to finish the active database task, then exceed the existing
Vitest coverage gate and complete Minitest coverage for public/protected behavior.

## Purpose and scope

Raise evidence quality for the current repository without weakening coverage configuration or
changing application behavior only to satisfy a percentage. Add tests at existing public boundaries
for real reachable behavior. Preserve unrelated uncommitted work. CI and environment-construction
changes are excluded.

The Minitest inventory covers production Ruby under `app/` and `lib/`. Private methods are reached
through their public callers. Public/protected methods without a current product caller require an
explicit reachability disposition; reflection, direct private invocation and test-only production
seams do not count as coverage.

## Acceptance

- AC-1: `bun run test:coverage` passes all tests and the existing 99% statement, branch, function
  and line thresholds without changing thresholds, exclusions or source ignore annotations.
- AC-2: The full Rails Minitest suite passes on the final worktree, and the existing SimpleCov gates
  are reported without moving or lowering them.
- AC-3: Every reachable public/protected production Ruby method is exercised through a normal public
  product boundary. Every remaining uncovered public/protected method is classified by current
  source and caller evidence; no unreachable method is force-called through reflection.
- AC-4: Report full commands, measured results, red/green test changes, uncovered public/protected
  dispositions and any remaining acceptance blocker.

## Baseline and open constraints

The first Vitest run passed 640 tests but failed the unchanged global thresholds at 93.77%
statements, 92.96% branches, 90.19% functions and 93.78% lines. Two mocks targeted a moved Passkey
module, and one email-index assertion expected an edit link absent from the current server/component
contract. Those test-boundary mismatches were corrected. The latest coverage run passed 68 files and
696 tests at 100% statements, 99.7% branches (1,021/1,024), 100% functions and 100% lines. It passes
the existing 99% gates; no thresholds, exclusions or source ignore annotations were changed. Three
remaining uncovered branches are nullish fallbacks in `src/features/org_admin/AdminConfirmation.tsx`
whose typed component contract initializes and preserves their values as strings.

The 2026-11-12 full Minitest coverage run passed **7,669 tests, 51,530 assertions, zero failures,
errors or skips**. SimpleCov then exited 2 on the unchanged repository gates: line coverage
**86.15%** (30,479/35,376; minimum 98%), branch coverage **57.30%** (3,685/6,431; minimum 93%), and
method coverage **77.30%** (4,534/5,865; minimum 97%). This separates a green Rails test run from
the still-failing coverage gate; no thresholds or exclusions were changed. `bun run check` passes
after typed request fixtures and visit lifecycle helpers replaced unsafe untyped mock assertions.
The public/protected runtime inventory and uncovered-method dispositions are not complete; the
existing 2026-11-06 classification is stale and is not evidence for the current worktree. No
public/protected coverage-completion claim is made.

A fresh Rails runtime inventory joined to the 2026-11-12 SimpleCov report contains **4,377
owner/method rows**: **3,408 reached**, **752 uncovered rows** across **581 distinct source
locations**, and **217 rows** for which SimpleCov exposes no one-to-one method entry under the
inventory's source line/name mapping. This is preliminary measurement, not the completed AC-3
reachability audit; the 217 unmatched rows include generated aliases and concern methods whose
runtime owner differs from the source-level method label. Corrected visibility grouping is **3,155
public instance rows** (2,351 reached, 589 uncovered, 215 unmatched), **1,145 public class rows**
(1,009 reached, 134 uncovered, 2 unmatched), and **77 protected instance rows** (48 reached, 29
uncovered). The largest At that 2026-11-12 pre-retirement run, the largest uncovered groups included
`BrowserRpAuthentication` (29 rows), `FlowSignUp` (23), `FlowSignIn` (21), `AuthAdmissionBinding`
(18), `Base::App::ApplicationController::HelperMethods` (11), and `RefreshTokenShared::ClassMethods`
(10).

Pre-retirement source/caller findings from the 2026-11-12 audit: inspection confirmed that
`FlowSignIn` and `FlowSignUp` had no application include sites and require an ownership/deletion
review rather than synthetic calls. The `OpaqueAdmissionStore` has no current application caller.
`AuthAdmissionBinding` has no application include site; its methods call one another, and `SignFlow`
reads only its `CURFEW_DURATION` constant. `RefreshTokenShared` has no application include site or
current caller. These are not covered through fabricated test calls. Promotional unsubscribe edit
behavior is shadowed by the concrete surface controllers. Avatar owner APIs deliberately fail closed
before actions while Access's data API is absent; their success paths remain unreachable without
crossing the accepted service ownership boundary.

At the time of the 2026-11-12 coverage run, the `CoreRpBridge` concern had model-level coverage
through its real APP and ORG bridge models. The then-latest full-run method join reached all four
source-level public/protected methods recorded for the concern: `core_rp_bridge`, `actor`, `subject`
and `core?`. This preserves model-level checks for legacy and blank field normalization, external RP
identity preservation, actor/subject resolution, and Core versus non-Core classification. SimpleCov
separately reports generated `class_attribute` accessors; these are not source-level owner/method
inventory rows and no tests were added solely to exercise unused generated accessors. This is a
historical pre-retirement inventory: `actor`, `subject` and `core?` no longer exist in Governance
after the 2026-11-13 owner decision.

The public `AuthMethodGuard` entry points are now covered through policy tests against persisted
Client and Operator credential state. The tests exercise refusing removal of a sole sign-in or
step-up method, allowing removal when a usable alternative remains, and the ADVANCED Operator's
two-passkey minimum. The 2026-11-12 method inventory reached all six public class methods. The
focused test file passed **5 tests / 9 assertions / 0 failures / 0 errors / 0 skips** in that run;
the 2026-11-13 full coverage run also includes it, but no public/protected method inventory join was
rerun after the ceremony retirement.

Two additional real Base APP request tests reach protected Browser RP methods without a test-only
controller. A same-origin Fetch Metadata header paired with a foreign Origin is rejected before
Preference rows or audit rows change, reaching `browser_rp_trusted_origins`. A malformed RP
credential on JSON Home returns 401, clears both RP cookies, and reaches
`render_browser_rp_invalid_credentials!`. The focused tests passed **1 test / 7 assertions** and **1
test / 13 assertions**, respectively; both are included in the latest full test run. The first
origin-test attempt had an invalid array argument to `assert_no_difference`; that test assertion was
corrected before the request test passed.

The pre-retirement `IdentityStepUpCeremonyContract` decode path had no application consumer of
`IdentityStepUpCeremonyGrant.decode` or `IdentityStepUpCeremonyResult.decode`; its result issuer,
`IdentityStepUpCeremonyError`, the orphan step-up email branch, and `OidcConnectionRecord` were
removed after fresh source and caller searches. The former WebAuthn configuration resolver and
value, boot initializer, and local static runtime guard were also removed. Governance keeps the live
RP step-up OIDC handoff and state, plus credential records and their owner-side persistence/audit
operations. Access owns all browser ceremony execution. See
[`evidence/2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](../../evidence/2026-11-13-remove-unreachable-ceremony-code-Q7M2.md).

These findings classify only the named hotspots. Most remaining uncovered locations still require
current caller evidence and reachability classification.

The APP and ORG membership-directory routes now have a real HTTP regression for the absent Access
authority. All seven routes in each realm return explicit 503 problem details, use `no-store`, do
not redirect, and do not return a fabricated empty account list. The focused run passed **1 test /
112 assertions / 0 failures / 0 errors / 0 skips**; targeted RuboCop passed. The route-level
authentication assertion is stubbed as an external-client boundary, while the Access data lookup and
fail-closed response remain real. The full Minitest coverage run above includes this test.

The 2026-11-12 full-run method inventory contained **4,377 rows: 3,408 reached, 752 uncovered across
581 source locations, and 217 unmatched**. By visibility: public instance **3,155 (2,351 reached /
589 uncovered / 215 unmatched)**; public class **1,145 (1,009 / 134 / 2)**; protected instance **77
(48 / 29 / 0)**. The reachability audit remains incomplete, so this task remains implementing.

## 2026-11-13 reachability disposition

The owner confirmed that Access runs all authentication ceremonies and Governance runs none. The
unreachable flow concerns, admission store and binding, refresh-token sharing concern, unused OIDC
connection concern, step-up grant/result codecs and issuer, and sign-in binding codecs were removed
after current application-source searches found no caller. The unused `CoreRpBridge#actor`,
`#subject` and `#core?` methods were removed; the bridge models, associations, persistence, and
schema remain. The live withdrawal lifecycle remains on `FlowBase`; its sign-flow-only transition
machinery was removed. Identity and credential records, and RP step-up paths with current callers,
remain. No database schema or records were changed. The reusable WebAuthn security-invariant test
remains enabled; only the local ceremony configuration resolver, value, and boot initializer were
removed. See
[`evidence/2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](../../evidence/2026-11-13-remove-unreachable-ceremony-code-Q7M2.md).

The final 2026-11-13 ceremony-retirement run passed **7,490 Minitest tests, 49,487 assertions, zero
failures, errors or skips**. SimpleCov exited 2 on the unchanged thresholds: line coverage
**88.45%** (29,132/32,933; minimum 98%), branch coverage **59.57%** (3,451/5,793; minimum 93%), and
method coverage **81.09%** (4,237/5,225; minimum 97%). The 2026-11-12 pre-retirement measurement was
86.15% line, 57.30% branch and 77.30% method. Source and test inventories changed during retirement,
so their denominators and runtime test counts are not one-to-one comparisons. The current coverage
thresholds remain unmet; this retirement does not close the coverage-completion acceptance.

## 2026-11-13 coverage completion pass

In the earlier 2026-11-13 pass, `bun run test:coverage` passed **59 files / 588 tests**. The
configured v8 report measured **100% statements (1,072/1,072), branches (824/824), functions
(360/360), and lines (1,045/1,045)**. No thresholds, exclusions, or source ignore annotations
changed.

That pass's full `COVERAGE=true bin/rails test` run passed **7,512 tests / 49,713 assertions**, with
zero failures, errors, or skips. The command exited 2 only because SimpleCov's existing minimums
remain unmet: **89.05% line (29,238/32,832; minimum 98%), 60.46% branch (3,485/5,764; minimum 93%),
and 82.51% method (4,295/5,205; minimum 97%)**. The coverage settings were not changed.

That pass's runtime method join contained **2,726 public/protected rows**: **2,279 reached, 277
uncovered, and 170 unmatched** (generated aliases or methods without a one-to-one source-level
SimpleCov entry). Visibility counts are public instance **1,632 (1,260 reached / 204 uncovered / 168
unmatched)**, public class **1,017 (970 / 45 / 2)**, and protected instance **77 (49 / 28 / 0)**.
The 277 uncovered rows map to 245 source locations. This pass added coverage through preference
screen PATCHes, avatar ownership and lifecycle helpers, actor and credential predicates, and Base
APP / ORG failure boundaries. It corrected `Actor::StepUp.null`, which had raised
`NameError: uninitialized constant Actor::NULL`; its focused test first failed with that error and
passed after the implementation referenced `Actor::StepUp::NULL`.

That pass's source searches confirmed that the uncovered Avatar, membership-directory, IAM, and
Support owner API action bodies are stopped by `authenticate_avatar_caller!` while Access's owner
data API is absent. Existing request tests assert explicit unavailability and unchanged owner state.
The Base APP Secret index also returns a fail-closed 503 before its action body can read data. Other
uncovered rows include methods without a current product caller, configuration/environment
construction helpers, and external owner paths that remain unavailable. The updated inventory is
`tmp/coverage-public-protected-uncovered.txt` and is temporary tooling output, not a tracked
artifact.

**AC-1 is met. AC-2's full Minitest run is green, with the SimpleCov gate failure reported above.
AC-3 remains open:** the refreshed inventory still has 277 uncovered rows, and a per-method current
caller/reachability disposition has not been completed for all of them. No reflection or synthetic
private-method calls were added. Keep this specification in `implementing` status.

## Latest 2026-11-13 coverage recheck

The latest `bun run test:coverage` result remains the 59-file / 588-test run recorded above. It was
not rerun because no JavaScript or TypeScript source changed afterward. No coverage threshold,
exclusion or source ignore annotation changed.

The latest `COVERAGE=true bin/rails test` run executed **7,513 tests / 49,705 assertions**, with
zero failures, errors or skips. Its process exited 2 because the existing SimpleCov minimums remain
unmet: **89.16% line (29,246/32,800; minimum 98%), 60.70% branch (3,496/5,759; minimum 93%), and
83.17% method (4,321/5,195; minimum 97%)**. A separate non-coverage full run had the same 7,513
tests and 49,702 assertions; the three-assertion difference between runs is unexplained. Coverage
denominators changed with the combined source/test worktree and are not directly comparable to the
earlier measurement.

The latest public/protected runtime inventory contains **2,716 rows**: **2,274 reached, 263
uncovered across 234 source locations, and 179 unmatched** to a one-to-one source-level SimpleCov
method. Visibility counts are public instance **1,625 (1,261 reached / 196 uncovered / 168
unmatched)**, public class **1,015 (964 / 40 / 11)**, and protected instance **76 (49 / 27 / 0)**.
The updated temporary uncovered inventory is
`tmp/coverage-public-protected-uncovered-2026-11-13-normalized.txt`.

This work order sequence added real request coverage for the APP/ORG passkey index and the
Withdrawal re-entry page, value coverage for actor/authentication-context predicates, and a static
guard that rejected the obsolete `AccessPolicy` declaration path before it was removed. The focused
tests and current full suite are recorded in
[`evidence/2026-11-13-coverage-completion-N6D2.md`](../../evidence/2026-11-13-coverage-completion-N6D2.md).

**AC-1 remains met on the latest tested frontend source. AC-2's test run passes, but its SimpleCov
gate remains below threshold. AC-3 remains open:** 263 mapped public/protected methods are still
uncovered and 179 runtime rows remain unmatched; a current caller/reachability disposition has not
been completed for every row. No reflection, private-method calls or synthetic test-only product
paths were added. Keep this specification in `implementing` status.

## Final 2026-11-13 coverage pass

The latest focused request run passed **24 tests / 165 assertions / 0 failures / 0 errors / 0
skips**. It covers the public Withdrawal re-entry page and generic message, APP TOTP and APP/ORG
passkey details under fresh step-up evidence, the ORG birthdate detail boundary, the IAM revocation
page, and nested Support enforcement pages and mutations refusing while Access-owned data is
unavailable. The missing Access root-session lookup during Withdrawal scheduling was reproduced as a
`NoMethodError` before the change. The request now returns the existing explicit 503 JSON contract
and persists no flow or audit event. The focused test passed after the explicit fail-closed change.

The APP and ORG RP root-feature refusal tests also exercise every Secrets, Secret Issuance, Secret
Presentation and ORG Secret Credential HTTP method, verifying explicit no-store 503 responses and
unchanged credential/issuance counts. Those two request tests passed **2 tests / 85 assertions**.

The fresh full coverage-enabled Rails run passed **7,517 tests / 49,959 assertions**, with zero
failures, errors or skips. Nine worker-thread `AccessOpDataUnavailableError` reports appeared in
concurrency tests for administrative access locks, enforcement reconciliation and operator
availability; Minitest counted no test error. SimpleCov exited 2 on unchanged thresholds: **90.15%
line (30,225/33,526; minimum 98%), 61.65% branch (3,499/5,675; minimum 93%), and 84.87% method
(4,348/5,123; minimum 97%)**. No coverage settings, exclusions or source annotations changed. The
run is recorded in
[`evidence/2026-11-13-coverage-completion-T8R3.md`](../../evidence/2026-11-13-coverage-completion-T8R3.md).

The refreshed Rails runtime inventory has **2,657 public/protected rows**. Combining the 17 raw
parallel resultsets by SimpleCov source location shows **2,294 exact reached rows**, **29 rows with
a hit from a different runtime method sharing the same source start line**, **192 still uncovered
rows across 175 source locations**, and **142 rows without a one-to-one coverage method match** (137
with no report location, 5 with a name mismatch). Visibility grouping is public instance **1,593
(1,281 exact reached / 21 same-location / 149 uncovered / 142 unmatched)**, public class **997 (964
/ 8 / 25 / 0)**, and protected instance **67 (49 / 0 / 18 / 0)**. The raw tuple union finds 67 more
exact method hits than the merged report's row join; method-level counts are therefore reported
separately from the official aggregate SimpleCov thresholds.

Model-boundary additions now exercise the Operator `SecretCredential` kind and lifecycle predicates
and the `WithdrawalFlow#status_name_for` instance delegation. An exploratory call also found that
the unused `HandleAssignment#name` delegated to a nonexistent `Handle#name`; a repository caller
search found no consumer, so the broken delegate was removed instead of introducing a new display
API.

The caller audit confirms that Access-owned Avatar, membership, IAM and Support endpoints stop at
the Access authority check; tests assert explicit unavailable responses and unchanged state. The
OP-backed verification completion/cancellation paths also fail closed until their owner API exists.
Generated helper aliases and source methods without a matching instrumented entry are recorded as
coverage-mapping limitations. The complete row-by-row reachability disposition is still unfinished:
the remaining 192 mapped misses and 142 unmatched runtime rows include other current caller and
no-caller cases that have not all received a documented disposition. No reflection or synthetic
private-method invocation was added. Keep AC-3 open and this specification in `implementing` status.

## Latest 2026-11-13 coverage recheck

The latest `bun run test:coverage` passed **59 files / 588 tests** at **100% statements
(1,072/1,072), branches (824/824), functions (360/360), and lines (1,045/1,045)**. No JavaScript or
TypeScript coverage configuration changed.

The latest coverage-enabled Rails run passed **7,499 tests / 50,191 assertions** with zero failures,
errors or skips. SimpleCov exited 2 on the unchanged minimums: **90.37% line (30,135/33,343; minimum
98%), 62.01% branch (3,501/5,645; minimum 93%), and 85.62% method (4,353/5,084; minimum 97%)**. The
full latest verification and reachability dispositions are in
[`evidence/2026-11-13-coverage-reachability-L6N2.md`](../../evidence/2026-11-13-coverage-reachability-L6N2.md).

After confirming there was no callback/caller or superclass implementation, six protected
`track_authenticated_session_activity?` overrides were removed. The unused `SurfaceRouteAliasHelper`
was removed after source and route inventories found no consumers of its mapped prefixes. The
current lifecycle documentation now records that session-activity tracking is not in the request
path. Relevant APP/ORG and Tech request tests pass; no database, credential, CI or frontend behavior
was changed.

The refreshed runtime inventory has **2,590 public/protected rows**: **2,297 exact hits**, **137
uncovered method bodies**, **135 generated methods without a one-to-one SimpleCov location**, and
**21 aliases sharing a source line with another instrumented method**. Every row now has a current
caller/reachability disposition in the linked evidence. The 137 uncovered bodies are either stopped
before action execution by the explicit unavailable Access authority boundary, maintenance/config
entrypoints, or methods with no current application caller. The evidence calls out two unresolved
contract discrepancies at that checkpoint: no app caller for `CredentialDeletionFinalizer.register`
despite its ADR, and no current writer caller for the previously accepted `preferences_changed`
audit API. The later public/protected revalidation below wired and tested the finalizer
registration; the missing preference-audit writer remains unresolved.

**AC-1 is met. AC-2's Rails test suite is green, while its existing SimpleCov gates remain unmet and
make the command exit 2. AC-3's current method inventory and dispositions are complete; blocked
Access-owned success paths are not claimed as covered. AC-4's commands, outcomes and remaining
limits are recorded.** The coverage gates and two contract discrepancies remain open, so the
specification remains `implementing`.

## Post-ceremony coverage revalidation (2026-11-13)

After the unreachable-ceremony cleanup, `bun run test:coverage` was rerun against the current
frontend tree: **59 files / 588 tests**, with **100% statements (1,072/1,072), branches (824/824),
functions (360/360), and lines (1,045/1,045)**. No coverage threshold or exclusion changed.

The full Rails suite after that cleanup passed **7,492 tests / 50,156 assertions**, with no
failures, errors or skips. SimpleCov still exits 2 against the unchanged thresholds: **90.37% line,
62.03% branch, and 85.57% method**. The current runtime inventory was refreshed after cleanup and
joined to the 17 raw resultsets with `SimpleCov::Combine::MethodsCombiner`: **2,576 public/protected
rows**, **2,283 exact hits**, **137 uncovered methods**, **135 rows without a one-to-one coverage
location**, and **21 same-line aliases**. Comparing by source path and method name shows the 137
misses are identical to the previously dispositioned set; cleanup removed old rows and shifted
source lines. No new public/protected miss was introduced. Their caller/reachability dispositions
remain in `evidence/2026-11-13-coverage-reachability-L6N2.md`.

The two existing contract discrepancies recorded there remain open, as do the unchanged SimpleCov
gates. This refresh changes no application code or tests and does not close the overall coverage
specification; status remains `implementing`. Full current evidence is in
[`evidence/2026-11-13-coverage-post-ceremony-R7M4.md`](../../evidence/2026-11-13-coverage-post-ceremony-R7M4.md).

## Public/protected coverage revalidation (2026-11-13)

The current coverage pass added a real caller for `CredentialDeletionFinalizer.register` from
`BrowserRpAuthentication#clear_browser_rp_access_cookie!`. A confirmed access-cookie deletion is now
registered before the exception renderer can replace the response, while the finalizer still
preserves a later same-name cookie write and unrelated cookie changes. The failure case was observed
before the caller was added: the exception response lost the deletion header. The middleware request
test now asserts that a 404 replacement response retains only the access-cookie deletion. It also
checks non-duplication and rejects a blank cookie name.

`ClientContactAuditOutbox.record_preferences_changed!` now has direct public-contract coverage for
committed promotional and notification changes, unchanged values, mismatched owners, and calls
outside the source transaction. A search still finds no application preference writer calling this
audit API. No preference workflow or audit writer was invented; the missing product caller remains
an implementation discrepancy for its owner.

The focused run passed **11 tests / 48 assertions / 0 failures / 0 errors / 0 skips**. Targeted
RuboCop passed for the concern and two test files with no offenses. The subsequent full
coverage-enabled Minitest run passed **7,500 tests / 50,188 assertions / 0 failures / 0 errors / 0
skips**. SimpleCov exited 2 against the unchanged thresholds: line **90.42% (30,119/33,307; minimum
98%)**, branch **62.11% (3,506/5,644; minimum 93%)**, and method **85.59% (4,339/5,069; minimum
97%)**. No coverage threshold, exclusion, or source ignore annotation changed.

The refreshed runtime method join contains **2,576 public/protected rows**: **2,285 reached**, **135
uncovered**, **135 without a one-to-one coverage location**, and **21 same-line name mismatches**.
By visibility, public instance has **1,603 rows (1,344 reached / 105 uncovered / 135 without a
location / 19 mismatches)**, public class has **912 (892 / 18 / 0 / 2)**, and protected instance has
**61 (49 / 12 / 0 / 0)**. The two newly reached methods are
`ClientContactAuditOutbox.record_preferences_changed!` and `CredentialDeletionFinalizer.register`.
The remaining 135 uncovered methods match the already dispositioned set in
[`evidence/2026-11-13-coverage-reachability-L6N2.md`](../../evidence/2026-11-13-coverage-reachability-L6N2.md);
the location-less and same-line rows remain SimpleCov-to-runtime mapping limits, not claims of
coverage.

Current results and the TDD red/green observations are recorded in
[`evidence/2026-11-13-coverage-public-protected-revalidation-J8V4.md`](../../evidence/2026-11-13-coverage-public-protected-revalidation-J8V4.md).
Vitest remains at its previously verified 100% across statements, branches, functions, and lines; no
JavaScript or TypeScript source changed in this pass. **AC-1 remains met. AC-2's test run is green
but the existing SimpleCov gates remain unmet. AC-3 retains its current method dispositions, with
the two reachable misses now covered; the preference audit writer discrepancy remains open. AC-4 is
updated by the linked evidence.** The overall specification remains `implementing`.

## Final current-tree coverage recheck (2026-11-13)

After the static-scan-only replacement of ten fixed Avatar transfer test UUIDs with valid
`SecureRandom.uuid` values, the current full coverage-enabled Rails suite passed **7,500 tests /
50,188 assertions / 0 failures / 0 errors / 0 skips**. SimpleCov exited 2 on the unchanged minimums:
line **90.42% (30,119/33,307; minimum 98%)**, branch **62.11% (3,506/5,644; minimum 93%)**, and
method **85.69% (4,344/5,069; minimum 97%)**. A separate coverage-disabled full run passed **7,500
tests / 50,185 assertions / 0 failures / 0 errors / 0 skips**; the three-assertion difference is
unexplained. Both runs included the current test fixture values.

The latest 17-resultset join still contains **2,576 public/protected rows: 2,285 reached, 135
uncovered, 135 without a one-to-one coverage location, and 21 same-line name mismatches**. The two
methods added in the prior pass remain reached, and the uncovered identities match the previously
documented dispositions. There are still no JavaScript or TypeScript changes since the latest Vitest
run of 59 files / 588 tests at 100% for statements, branches, functions, and lines.

The current commands, per-visibility inventory, and limits are recorded in
[`evidence/2026-11-13-coverage-public-protected-final-recheck-P8M2.md`](../../evidence/2026-11-13-coverage-public-protected-final-recheck-P8M2.md).
**AC-1 remains met. AC-2's full test suite is green, with the existing SimpleCov thresholds reported
as unmet. AC-3's current reachable-method inventory and remaining dispositions are documented; the
preference audit API still lacks an application writer. AC-4 is updated.** Keep the specification in
`implementing` status because the aggregate SimpleCov gates and the preference audit writer
discrepancy remain open.

## Callable public contract coverage follow-up (2026-11-13)

Three Minitest files now cover the public quota result methods on APP and ORG principals,
`AccountStandingResolver.call` against each realm's real PostgreSQL connection, and the configured
secret issuance/proof-retention duration accessors. The quota tests cover active owners with
remaining capacity and inactive owners with no capacity. The duration tests cover positive values,
zero/negative rejection, and a missing required value. The focused run passed **6 tests / 41
assertions / 0 failures / 0 errors / 0 skips**; targeted RuboCop passed for all three files.

The full coverage-enabled Rails suite passed **7,506 tests / 50,226 assertions / 0 failures / 0
errors / 0 skips**. SimpleCov exited 2 against the unchanged gates: **90.45% line (30,128/33,307;
minimum 98%), 62.15% branch (3,508/5,644; minimum 93%), and 85.83% method (4,351/5,069; minimum
97%)**. The full coverage-disabled run also passed **7,506 / 50,226** with zero failures, errors, or
skips and exit code 0. Both full runs printed the existing `AccessOpDataUnavailableError` reports
from concurrency worker threads; Minitest recorded no errors.

The fresh 17-resultset join contains **2,576 public/protected rows**: **2,292 reached, 128 missed,
135 without a one-to-one SimpleCov location, and 21 same-line name mismatches**. The seven newly
reached methods are the four quota result methods, `AccountStandingResolver.call`, and the issuance
TTL and proof-retention accessors. The 135 location-less rows and 21 name mismatches remain mapping
limits and are not counted as reached. The latest join is in ignored temporary output at
`tmp/coverage-task/public-protected-joined-after-callable-tests-2026-11-13.json`.

The **128** remaining misses are the same categories documented in the current reachability audit,
after removing the seven methods now reached. Current request tests cover the explicit fail-closed
boundary for controller paths whose successful owner-data bodies require the absent Access API; the
unavailable success bodies are not called directly. The other remaining rows are generated bridge
class-attribute predicates, legacy policy hooks retained under the accepted Operator Capability ADR,
maintenance/configuration entrypoints, and methods without a current application caller. No
reflection, synthetic product path, environment-construction test, threshold change, exclusion, or
source ignore was added. The missing application caller for preference-change audit writing remains
a separate contract discrepancy.

No JavaScript or TypeScript source changed. The latest previously verified Vitest run remains **59
files / 588 tests** at **100% statements, branches, functions, and lines**. AC-1 remains met. AC-2's
Minitest suite passes, but its SimpleCov gates remain unmet. AC-3's current caller dispositions are
revalidated; Access-owned success paths and maintenance/configuration-only methods remain outside
ordinary Minitest reachability. AC-4 is updated by
[`evidence/2026-11-13-coverage-public-contract-reachability-J2L6.md`](../../evidence/2026-11-13-coverage-public-contract-reachability-J2L6.md).
Keep the specification in `implementing` status because the aggregate SimpleCov gates and the
preference audit writer discrepancy remain open.

## Current-tree coverage after OIDC registry retirement (2026-11-13)

The unused shared-secret OIDC client-authentication path was removed from `OidcClientRegistry`:
first-party client configuration no longer loads or exposes a `client_secret`, the uncalled
`authenticate(client_id, secret_credential)` entrypoint and its private secret resolver were
deleted, and `app/resolvers/oidc_client_secret_resolver.rb` was removed. Current product callers use
`authenticate_assertion`; a source search finds no remaining references to the removed method,
resolver, or helper. This does not remove the separate Client Secret credential lifecycle or its
owner-side operations. The registry test now asserts that a client configuration does not expose a
secret and that the legacy authentication method is absent.

The focused registry test passed **7 tests / 43 assertions / 0 failures / 0 errors / 0 skips**.
Targeted RuboCop passed for the registry and test (2 files, no offenses), and
`bin/rails zeitwerk:check` reported `All is good!`. There was no Red run for the dead-method
deletion: the removed entrypoint had no current application caller, so a synthetic invocation would
not establish product behavior. The added absence assertions and existing assertion-authentication
cases passed.

The current full coverage-enabled Rails run passed **7,506 tests / 50,227 assertions / 0 failures /
0 errors / 0 skips**. SimpleCov exited 2 on its unchanged thresholds: line **90.46% (30,118/33,293;
minimum 98%)**, branch **62.17% (3,508/5,642; minimum 93%)**, and method **85.76% (4,344/5,065;
minimum 97%)**. No thresholds, exclusions or source ignore annotations changed. In this run,
parallel concurrency tests also printed `AccessOpDataUnavailableError` from worker threads; Minitest
recorded no test errors.

The final Vitest run passed **59 files / 588 tests** with **100% statements (1,072/1,072), branches
(824/824), functions (360/360), and lines (1,045/1,045)**. Its configured 99% thresholds were not
changed.

The fresh Rails runtime inventory was joined to the 17 SimpleCov worker resultsets with
`SimpleCov::Combine::MethodsCombiner`. It contains **2,574 public/protected rows**: **2,291 reached,
127 missed, 135 without a one-to-one SimpleCov location, and 21 same-line name mismatches**.

| Visibility         |      Rows |   Reached |  Missed | No one-to-one location | Same-line mismatch |
| ------------------ | --------: | --------: | ------: | ---------------------: | -----------------: |
| Public instance    |     1,603 |     1,348 |     101 |                    135 |                 19 |
| Public class       |       910 |       894 |      14 |                      0 |                  2 |
| Protected instance |        61 |        49 |      12 |                      0 |                  0 |
| **Total**          | **2,574** | **2,291** | **127** |                **135** |             **21** |

Compared by source path and method name with the prior 128 misses, the current inventory has 127
identical misses, zero new misses, and no longer lists `OidcClientRegistry.authenticate`. The 103
controller action bodies remain behind the explicit unavailable Access owner API; their HTTP
entrypoints retain tested fail-closed responses. The other 24 methods remain in the previously
documented policy, generated-accessor, maintenance/configuration, or no-current-caller categories.
The current source/caller dispositions are linked in
[`evidence/2026-11-13-coverage-oidc-registry-retirement-V9C2.md`](../../evidence/2026-11-13-coverage-oidc-registry-retirement-V9C2.md).
The `CredentialDeletionFinalizer.register` discrepancy in the older L6N2 evidence is superseded by
the public caller and request test recorded in J8V4. The preference audit API still lacks an
application writer. The 135 unmatched locations and 21 same-line mappings are not counted as
reached.

**AC-1 is met. AC-2's Minitest run is green while its unchanged SimpleCov gates remain unmet. AC-3
has no newly missed reachable method; the current 127 misses retain explicit dispositions and the
blocked Access-owned success bodies are not reported as covered. AC-4 is updated by the linked
evidence.** Keep this specification in `implementing` status because the aggregate SimpleCov gates
and preference-audit writer discrepancy remain open.

## Current resumption after public-contract additions (2026-11-13)

This resumption added tests for the OperatorTelephone public-ID backfill entrypoint, RP principal
policy lookup, generated Core bridge predicates, and the Turnstile public site-key accessor. A new
Red/Green regression assertion first failed while the uncalled
`JitSecurityJwtJwksService.normalized_public_jwk` method was still exposed. The unused wrapper and
its now-unused requires were then removed; the focused JWT selection passed **38 tests / 254
assertions**. Two other uncalled Valkey entrypoints, `Settings#[]` and
`ResponsibilityUrls.require_url`, were removed after source searches found no callers. The Valkey
responsibility ADR now identifies the older URL resolver as superseded by the current Settings
loader. No schema, credentials or CI file changed.

The targeted additions passed: backfill **6 tests / 16 assertions**, RP policy lookup **1 / 3**,
Core bridge predicates **1 / 12**, Turnstile site-key accessor **1 / 1**, and the Valkey settings,
URL and infrastructure selection **17 / 86**. The current relevant Ruby files pass targeted RuboCop
(**9 files, no offenses**) and `git diff --check` passes.

The reproducible full coverage-enabled Rails run passed **7,516 tests / 50,260 assertions / 0
failures / 0 errors / 0 skips**. Nine worker-thread `AccessOpDataUnavailableError` reports appeared
in the administrative-access and enforcement-reconciliation concurrency tests; Minitest recorded no
errors. SimpleCov exited **2** on the unchanged thresholds: line **90.51% (30,120 / 33,275; minimum
98%)**, branch **62.24% (3,511 / 5,641; minimum 93%)**, and method **85.89% (4,348 / 5,062; minimum
97%)**. The full run's stdout is retained outside the repository at
`/tmp/umaxica-coverage-resumption-2026-11-13.log`.

The fresh runtime inventory joined to all 17 parallel resultsets contains **2,571 public/protected
rows**:

| Visibility         |      Rows |   Reached |  Missed | No SimpleCov location | Same-line name mismatch |
| ------------------ | --------: | --------: | ------: | --------------------: | ----------------------: |
| Public instance    |     1,602 |     1,349 |      99 |                   135 |                      19 |
| Public class       |       908 |       902 |       4 |                     0 |                       2 |
| Protected instance |        61 |        49 |      12 |                     0 |                       0 |
| **Total**          | **2,571** | **2,300** | **115** |               **135** |                  **21** |

The 115 exact misses now have current caller dispositions. **103 are controller or controller-
concern entrypoints** whose action bodies stop at the missing Access owner-data/API boundary or the
removed OP source; real request tests assert explicit unavailability and unchanged protected state.
**Two** `OrgIamOwnerMutationOperation` methods are called only after that unavailable IAM boundary.
**Seven** `ApplicationPolicy` role helpers have no current caller and remain under the accepted
Operator Capability ADR. The final three are a tracked-file maintenance writer
(`ArchitectureBaseline.write`), the unused test-database configuration report, and the
configuration-only diagnostic getter `Umaxica::Valkey::Settings#performance`. No action body or
protected helper was invoked through reflection or a synthetic test-only product route.

The 135 rows without a SimpleCov method location are generated readers/writers and other runtime
accessors which do not have a one-to-one instrumented method entry. The 21 same-line mismatches are
generated aliases or accessor writers that SimpleCov attributes to another runtime name. These
mapping rows are not counted as reached. The current row-level join and inventory remain ignored
temporary files under `tmp/coverage-task/`.

After the full suite, fixture loading toggled the migration-owned `NOT VALID` flags in the
disposable APP Setting, ORG Setting and Occurrence test databases. Following the already-recorded
recovery procedure, only those three test writers were confirmed to have zero active sessions, then
individually dropped, recreated and migrated. Their receipts and restored catalog state are: APP
Setting **17/17 migrations, 5 unvalidated FKs**; ORG Setting **17/17, 9**; Occurrence **118/118,
63**. All three have zero unvalidated CHECK constraints. No tests were run after this restore,
because fixture loading would toggle the flags again. The migration-owned files still carry the
separate 79-FK approval requirement.

The latest read-only `env RUBYOPT=-W0 RAILS_ENV=test bundle exec database_consistency` run exited
**1** with the single previously characterized partial JSON-expression index warning on
`OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`; no checker config or exclusion was
added. No JavaScript or TypeScript changed, so the previous Vitest result remains **59 files / 588
tests, 100% statements, branches, functions and lines**; it was not rerun.

**AC-1 remains met. AC-2's Minitest behavior run is green but SimpleCov remains below threshold.
AC-3's 115 exact misses have dispositions; the blocked owner-data paths and 156 non-one-to-one
mapping rows prevent a claim of complete per-method coverage. AC-4 is updated by
[`evidence/2026-11-13-coverage-current-resumption-Z9P4.md`](../../evidence/2026-11-13-coverage-current-resumption-Z9P4.md).
Keep the specification in `implementing` status.** The separate preference-audit writer discrepancy
and 79-FK approval remain open.

## Public request-context accessor coverage follow-up (2026-11-13)

The previous full coverage result was **90.51% line, 62.24% branch, and 85.89% method** against
unchanged minimums of **98%, 93%, and 97%**. The remaining public/protected misses retain the
owner-boundary and no-current-caller dispositions recorded above.

A repository-wide search found that the eleven private `PreferenceGlobal#request_context_*`
accessors had no literal caller. An attempted removal failed the existing
`ExplicitContextAccessorsTest`, which preserves their private zero-argument contract on consumers
and subclasses. The methods were restored. Instead, public `request_context` now dispatches each of
the twelve fixed `RequestContextContract.public_keys` through its corresponding private accessor and
raises for an unsupported key. The existing public context contract and real request tests cover
these paths; no private-method test seam or test-only production code was added.

The focused context, integration, and RI routing tests passed **64 runs / 867 assertions**, and
targeted RuboCop passed. The latest coverage-enabled full run passed **7,516 tests / 50,265
assertions / 0 failures / 0 errors / 0 skips**. SimpleCov exited **2** only on the unchanged
minimums: **90.55% line (30,143 / 33,288), 62.31% branch (3,523 / 5,654), and 86.13% method (4,360 /
5,062)**. Compared with the prior result, this pass improved line by 0.04 points, branch by 0.07
points, and method by 0.24 points; no threshold, exclusion, or ignore annotation changed.

An intermediate coverage run reported 17 Minitest failures after the accessor-removal experiment.
The removal was reverted; a coverage-disabled full run and the final coverage-enabled full run both
passed with zero failures. The intermediate failures did not reproduce. The failed removal itself is
not counted as coverage progress.

**AC-2 remains open because all three aggregate minimums remain unmet.** The specification stays in
`implementing` status. Current run details are in
[`2026-11-13-coverage-context-accessors-B6P3.md`](../../evidence/2026-11-13-coverage-context-accessors-B6P3.md).

## Public/protected coverage resumption (2026-11-14)

The operation-level step-up test now authenticates a real RP access token through
`RpRequestAuthenticator.call`, disables the persisted local RP principal after authentication, then
calls the public `RpStepUpStartIssuer.call`. The issuer refuses with `rp_binding_changed` and leaves
the pending state, audit outbox and RP session unchanged. The focused test passed **1 run / 10
assertions**. Together with the database-safety contract tests, the focused selection passed **14
runs / 84 assertions / 0 failures / 0 errors / 0 skips**.

A repository-wide source search found no current caller for
`Umaxica::TestEnvironment::DatabaseSafety.report`; only historical evidence mentions it. The method
was removed. `verify!`, `verify_catalog!` and `prepare_database_names!` remain because application
initialization, database-preparation tasks, the E2E server and tests use those safety boundaries.
After Rails initialization, a direct public-interface check confirmed that `DatabaseSafety.report`
is absent. This removes an unused diagnostic method without changing environment construction or
database schemas.

Targeted RuboCop passed for the five Ruby files in the focused change and test set,
`bin/rails zeitwerk:check` reported `All is good!`, and the read-only DatabaseConsistency run exited
**0** with no findings. The latest aggregate SimpleCov result remains the prior measured **90.56%
lines, 62.12% branches and 86.14% methods**, below unchanged minimums **98% / 93% / 97%**. No
aggregate coverage run was made in this slice, so the added test and removed method have not been
folded into refreshed totals. Vitest was not rerun because no JavaScript or TypeScript changed.

The specification remains `implementing`; aggregate coverage gates and the outstanding caller
inventory remain open. Details are in
[`evidence/2026-11-14-coverage-public-boundary-follow-up-COV2.md`](../../evidence/2026-11-14-coverage-public-boundary-follow-up-COV2.md).

## Coverage revalidation after Base RP redirect correction (2026-11-14)

The two `BaseSharedRpCellSelectionTest` cases removed the local RP session cookie but expected an
unauthenticated private HTML GET to return 401. The established Base RP contract redirects that
request with 303 to the same surface's sign entry and sets `no-store`. Both APP and ORG tests now
assert that exact local destination and retain the existing 503 assertion for unavailable Access
issuance. The focused tests passed **2 runs / 16 assertions**, and the related anonymous-root
redirect tests passed **3 runs / 17 assertions**. A later full verbose run passed **7,599 / 51,023**
with zero failures; one intermediate coverage run had two unclassified failures that did not
reproduce in the final coverage run.

The final full coverage run passed **7,599 / 51,031** with zero Minitest failures, errors or skips.
SimpleCov remains below unchanged minimums: **90.74% line (31,282 / 34,474), 62.14% branch (3,641 /
5,859), 88.10% method (4,668 / 5,298)** against **98% / 93% / 97%**. The current runtime inventory
has **2,626 public/protected rows**: **2,350 reached, 114 exact misses, 140 without one-to-one
instrumentation locations, and 22 same-line name mismatches**. The exact misses are 103
controller/concern owner-boundary paths and 11 non-controller paths retained or excluded under the
current contracts. Vitest passed **60 files / 594 tests**, with 100% statements, branches, functions
and lines. Test-database constraint state was restored after the Rails runs; see
[`evidence/2026-11-14-coverage-revalidation-R8M4.md`](../../evidence/2026-11-14-coverage-revalidation-R8M4.md).

**AC-1 remains met. AC-2 remains open because SimpleCov is below all three aggregate minimums. AC-3
remains open with 114 exact method misses and 162 instrumentation mapping rows. AC-4 is updated by
the linked evidence.** Keep the specification in `implementing` status.

## Coverage revalidation after maintenance-path coverage and Valkey cleanup (2026-11-14)

The live public/protected inventory now contains **2,624 rows**: **2,351 reached, 111 exact misses,
140 generated accessors without one-to-one instrumentation locations, and 22 same-line dynamic or
framework name mappings**. The 111 exact misses comprise 93 controller actions whose request paths
stop at unavailable Access owner-data boundaries, nine shared concern methods (fail-fast defaults,
owner API response handling, or verification helpers not reached in the current full-suite paths),
two ORG IAM mutations behind that boundary, and seven `ApplicationPolicy` helpers retained by the
accepted authorization design. Repository-wide search found no current code or test caller for
`VerificationBase#step_up_satisfied?`; that unused wrapper was removed while the used step-up and
bootstrap flows remained. The formerly uncovered `ArchitectureBaseline.write` path now has a public
Rake-task test; its temporary YAML write restores the exact prior bytes. The unused Valkey
`Settings#performance` responsibility was removed along with its development configuration entry.
Focused tests passed **13 / 70** for Valkey and the task, and **14 / 95** for the public step-up
flows. Targeted RuboCop passed for the changed Ruby files.

The final clean, single-worker full coverage run passed **7,600 runs / 51,032 assertions / 0
failures / 0 errors / 0 skips**. The command exited 2 because SimpleCov's unchanged minimums were
not met: **90.70% lines (31,265 / 34,470), 62.02% branches (3,634 / 5,859), and 88.16% methods
(4,669 / 5,296)** against **98% / 93% / 97%**. Earlier full runs had 6–18 CSRF-related failures; the
four-file focused CSRF run passed **44 / 1,218**, and the final full run did not reproduce them.
Their order-sensitive cause remains unconfirmed. Vitest remains at the previously verified **60
files / 594 tests**, with 100% statements, branches, functions, and lines.

After rebuilding only the disposable APP Setting, ORG Setting, and Occurrence test databases, their
migration receipts and unvalidated constraint counts returned to the expected values. The final
DatabaseConsistency run exited 0 with no findings and no checker configuration. No production,
shared, Queue, or other database was operated on. Full details and commands are in
[`evidence/2026-11-14-coverage-revalidation-R8M4.md`](../../evidence/2026-11-14-coverage-revalidation-R8M4.md).

**AC-1 remains met. AC-2 remains open because all three aggregate coverage minimums remain unmet,
although the final full Rails test run passed. AC-3 remains open with 111 exact misses, all
dispositioned by current ownership/reachability evidence. AC-4 is current in the linked evidence.**
Keep the specification in `implementing` status.

## CSRF test-order correction and coverage revalidation (2026-11-14)

The neutral RP entry contract test now enables CSRF protection on `ActionController::Base` and
restores the Rails configured default. Assigning the setting to the APP controller subclass had
created a subclass-local value, leaving later controller tests with CSRF disabled. The focused Red
run failed the subsequent APP theme first-write case (**2 runs / 5 assertions / 1 failure**); the
corrected selection passed (**2 / 9**) and the broader eight-file CSRF selection passed **84 /
1,511** with no failures, errors or skips. Targeted RuboCop passed.

The final coverage-enabled full Rails run passed **7,603 / 51,027** with no Minitest failures,
errors or skips. SimpleCov returned exit 2 on unchanged minimums: **90.73% lines (31,261/34,454),
62.14% branches (3,636/5,851), and 88.28% methods (4,670/5,290)** against **98% / 93% / 97%**.
Vitest passed **60 files / 594 tests** at 100% statements, branches, functions and lines. The
current public/protected join has **2,618 rows**: **2,352 reached, 104 exact misses, 140 rows
without a one-to-one SimpleCov location, and 22 name/line mismatches**. Exact misses include action
bodies stopped by the unavailable Access owner-data boundary; the tests retain fail-closed behavior
and do not bypass it.

Following the Rails run, only the disposable APP Setting, ORG Setting and Occurrence test databases
were individually rebuilt to restore their migration-owned validation state. The final test
DatabaseConsistency check exited 0 with no findings. Evidence, including the observed coverage
wrapper collection error and test database receipts, is recorded in
[`2026-11-14-coverage-csrf-order-fix-C9Q5.md`](../../evidence/2026-11-14-coverage-csrf-order-fix-C9Q5.md).

**AC-1 remains met. AC-2 remains open because SimpleCov is below all three unchanged minimums. AC-3
remains open with 104 exact public/protected misses and 162 instrumentation-mapping rows; the
Access-gated action bodies cannot be reached without changing the current ownership boundary. AC-4
is current in the linked evidence.** Keep the specification in `implementing` status.
