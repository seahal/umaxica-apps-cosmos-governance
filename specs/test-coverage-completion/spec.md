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
module, and one email-index assertion expected an edit link absent from the current
server/component contract. Those test-boundary mismatches were corrected. The latest coverage run
passed 68 files and 696 tests at 100% statements, 99.7% branches (1,021/1,024), 100% functions and
100% lines. It passes the existing 99% gates; no thresholds, exclusions or source ignore annotations
were changed. Three remaining uncovered branches are nullish fallbacks in
`src/features/org_admin/AdminConfirmation.tsx` whose typed component contract initializes and
preserves their values as strings.

The latest full Minitest coverage run passed **7,668 tests, 51,426 assertions, zero failures,
errors or skips**. SimpleCov then exited 2 on the unchanged repository gates: line coverage
**86.18%** (30,488/35,376; minimum 98%), branch coverage **57.33%** (3,687/6,431; minimum 93%),
and method coverage **77.30%** (4,534/5,865; minimum 97%). This separates a green Rails test run
from the still-failing coverage gate; no thresholds or exclusions were changed. An earlier
coverage-disabled full run passed before the latest test additions, so it is not treated as the
final-worktree result.
`bun run check` passes after typed request fixtures and visit lifecycle helpers replaced unsafe
untyped mock assertions. The public/protected runtime inventory and uncovered-method dispositions
are not complete; the existing 2026-11-06 classification is stale and is not evidence for the current
worktree. No public/protected coverage-completion claim is made.

A fresh Rails runtime inventory joined to the latest SimpleCov report contains **4,377 owner/method
rows**: **3,408 reached**, **752 uncovered rows** across **581 distinct source locations**, and
**217 rows** for which SimpleCov exposes no one-to-one method entry under the inventory's source
line/name mapping. This is preliminary measurement, not the completed AC-3 reachability audit; the
217 unmatched rows include generated aliases and concern methods whose runtime owner differs from
the source-level method label. Corrected visibility grouping is **3,155 public instance rows**
(2,351 reached, 589 uncovered, 215 unmatched), **1,145 public class rows** (1,009 reached, 134
uncovered, 2 unmatched), and **77 protected instance rows** (48 reached, 29 uncovered). The largest
uncovered groups now include
`BrowserRpAuthentication` (29 rows), `FlowSignUp` (23), `FlowSignIn` (21),
`AuthAdmissionBinding` (18), `Base::App::ApplicationController::HelperMethods` (11), and
`RefreshTokenShared::ClassMethods` (10).

Current source/caller inspection confirms that `FlowSignIn` and `FlowSignUp` have no application
include sites and require an ownership/deletion review rather than synthetic calls. The
`OpaqueAdmissionStore` has no current application caller. `AuthAdmissionBinding` has no application
include site; its methods call one another, and `SignFlow` reads only its `CURFEW_DURATION` constant.
`RefreshTokenShared` has no application include site or current caller. These are not covered through
fabricated test calls. Promotional unsubscribe edit behavior is shadowed by the concrete surface
controllers. Avatar owner APIs deliberately fail closed before actions while Access's data API is
absent; their success paths remain unreachable without crossing the accepted service ownership
boundary.

The `CoreRpBridge` concern now has model-level coverage through its real APP and ORG bridge models.
The latest full-run method join reaches all four source-level public/protected methods recorded for
the concern: `core_rp_bridge`, `actor`, `subject` and `core?`. This preserves model-level checks for
legacy and blank field normalization, external RP identity preservation, actor/subject resolution,
and Core versus non-Core classification. SimpleCov separately reports generated `class_attribute`
accessors; these are not source-level owner/method inventory rows and no tests were added solely to
exercise unused generated accessors.

The public `AuthMethodGuard` entry points are now covered through policy tests against persisted
Client and Operator credential state. The tests exercise refusing removal of a sole sign-in or
step-up method, allowing removal when a usable alternative remains, and the ADVANCED Operator's
two-passkey minimum. All six public class methods in the current method inventory are reached by the
latest SimpleCov join. The focused test file passed **5 tests / 9 assertions / 0 failures / 0 errors /
0 skips**; the full coverage run above includes it.

Two additional real Base APP request tests reach protected Browser RP methods without a test-only
controller. A same-origin Fetch Metadata header paired with a foreign Origin is rejected before
Preference rows or audit rows change, reaching `browser_rp_trusted_origins`. A malformed RP
credential on JSON Home returns 401, clears both RP cookies, and reaches
`render_browser_rp_invalid_credentials!`. The focused tests passed **1 test / 7 assertions** and
**1 test / 13 assertions**, respectively; both are included in the latest full test run. The first
origin-test attempt had an invalid array argument to `assert_no_difference`; that test assertion was
corrected before the request test passed.

The uncovered `IdentityStepUpCeremonyContract` decode path has no current application consumer of
`IdentityStepUpCeremonyGrant.decode` or `IdentityStepUpCeremonyResult.decode`; the result issuer also
has no application call site. Signed token integration remains unclassified for future owner/API
work and is not driven through synthetic calls in this repository task.

`OidcConnectionRecord` also has no application includer or caller in the current source search, but
it has not yet received a final ownership/deletion disposition. These findings classify only the
named hotspots. Most remaining uncovered locations still require current caller evidence and
reachability classification.
