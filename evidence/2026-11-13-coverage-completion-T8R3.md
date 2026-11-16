# Coverage Completion — Final 2026-11-13 Recheck

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The worktree has **968 changed or untracked paths** at final review, including substantial earlier
work. `.github/workflows/ci.yml` was already modified in that dirty tree; this pass did not edit it.
No commit, push, coverage threshold, exclusion, or source ignore annotation was made.

## Changes and focused verification

- Added a request test for the public Withdrawal ceremony re-entry page and its generic message.
- Added fresh step-up request coverage for APP TOTP detail, APP and ORG passkey details, and the ORG
  birthdate detail.
- Extended the fail-closed Access authority tests to nested Support enforcement approval, release,
  and appeal review pages and mutations, and the IAM grant revocation page.
- Expanded the APP and ORG RP root-feature refusal request tests to cover every Secrets, Secret
  Issuance, Secret Presentation and ORG Secret Credential HTTP method. Each request returned an
  explicit no-store 503 and preserved credential/issuance counts.
- Added model tests for Operator SecretCredential kind/status predicates and the
  `WithdrawalFlow#status_name_for` instance delegation.
- A fresh, valid Base APP step-up request reproduced a `NoMethodError` when Withdrawal scheduling
  had no Access root-session data. `withdrawal_current_session_public_id` now uses the verified
  session interfaces and raises `AccessOpDataUnavailableError` when neither contains an identifier.
  The request returns the established 503 JSON error and leaves withdrawal flows and audit events
  unchanged. This was Red before the implementation and Green afterward.
- An exploratory test call showed that `HandleAssignment#name` delegated to a nonexistent
  `Handle#name`. A repository search found no consumer; the broken delegate was removed instead of
  adding a new display API.

The focused command passed **24 tests / 165 assertions / 0 failures / 0 errors / 0 skips**:

```text
RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/controllers/base/org/support/enforcement_cases_controller_test.rb test/controllers/base/org/iam/grant_pages_test.rb test/controllers/base/app/identity/withdrawals_controller_test.rb test/controllers/base/org/identity/birthdates_controller_test.rb test/controllers/base/app/identity/totps_controller_test.rb test/controllers/base/app/identity/passkeys_controller_test.rb test/controllers/base/org/identity/passkeys_controller_test.rb
```

The latest focused model command passed **29 tests / 135 assertions / 0 failures / 0 errors / 0
skips**:

```text
RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/models/operator_secret_credential_test.rb test/models/withdrawal_flow_test.rb test/models/handle_assignment_test.rb
```

The APP and ORG fail-closed route checks passed **2 tests / 85 assertions / 0 failures / 0 errors /
0 skips**:

```text
RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/controllers/base/app/rp_root_feature_refusal_test.rb test/controllers/base/org/identity/rp_root_feature_refusal_test.rb
```

`bin/rubocop` on the fourteen changed Ruby files passed with no offenses. `git diff --check` on
those files passed. The first focused invocation used a shell-level
`POSTGRESQL_TEST_PREPARE_DATABASES` list that still named removed OP, Publishing, Search and RP-cell
test databases; the test safety guard rejected it before any DB work. The active test writer list
was then read from the current Rails test configuration and explicitly provided. No databases were
dropped or recreated.

## Full Rails suite and SimpleCov

The final coverage-enabled run passed **7,517 tests / 49,959 assertions**, with **0 failures, 0
errors and 0 skips**. Nine worker-thread `AccessOpDataUnavailableError` reports appeared in
concurrency tests for administrative access locks, enforcement reconciliation and operator
availability. Minitest counted no test error.

An intermediate full run exposed one time-dependent test error in the existing credential expiry
test: its fixed noon timestamp had moved before the new row's `created_at`. The test now derives its
decision time from `record.created_at`; the focused model run and the final full run both pass.

Command (output captured at `/tmp/umaxica-coverage-final-2026-11-13-004.log`):

```text
COVERAGE=true RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test
```

The process exited **2** because unchanged SimpleCov minimums remain unmet:

| Metric   |                   Result | Minimum |
| -------- | -----------------------: | ------: |
| Lines    | 90.15% (30,225 / 33,526) |     98% |
| Branches |   61.65% (3,499 / 5,675) |     93% |
| Methods  |   84.87% (4,348 / 5,123) |     97% |

The latest frontend coverage run was not repeated because this pass changed no JavaScript or
TypeScript. The prior `bun run test:coverage` result remains **59 files / 588 tests**, 100%
statements, branches, functions and lines.

## Public/protected method inventory

The Rails runtime inventory was regenerated after the suite. It contains **2,657** public/protected
rows. The 17 fresh parallel SimpleCov resultsets were also joined with the installed
`SimpleCov::Combine::MethodsCombiner`, which merges method tuples by source location. The row-level
classification is:

| Visibility         |     Total | Exact hit | Same start line, different runtime method | Uncovered | Unmatched |
| ------------------ | --------: | --------: | ----------------------------------------: | --------: | --------: |
| Public instance    |     1,593 |     1,281 |                                        21 |       149 |       142 |
| Public class       |       997 |       964 |                                         8 |        25 |         0 |
| Protected instance |        67 |        49 |                                         0 |        18 |         0 |
| **Total**          | **2,657** | **2,294** |                                    **29** |   **192** |   **142** |

The 192 uncovered rows span 175 source locations. The 142 unmatched rows have no report method at
the inventory line (137) or a different report method name there (5). The aggregate report's exact
row join marks 2,227 rows reached; the raw tuple union identifies 67 additional exact method hits.
This confirms a parallel merge/report attribution discrepancy. These raw counts do not replace the
official aggregate SimpleCov thresholds, and no source, vendor, threshold, or exclusion change was
made to affect that report.

Source/caller review confirms that Access-owned Avatar, membership, IAM and Support action bodies
are stopped by the missing Access authority API, and that the related request paths fail closed with
no owner-state mutation. The OP-backed verification completion and cancellation action bodies also
remain unavailable until their Access API is delivered. Generated helper aliases and methods with no
one-to-one SimpleCov entry are treated as inventory-mapping limitations rather than force-called by
reflection.

The complete current caller/reachability disposition is **not finished**: the 192 uncovered rows and
142 unmatched rows still include other current-caller and no-caller cases without a recorded per-row
disposition. No reflection, direct private invocation, synthetic product boundary, or test-only
application branch was added. AC-3 remains open and `specs/test-coverage-completion/spec.md` remains
`implementing`.
