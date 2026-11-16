# Public/Protected Coverage Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,078 changed or untracked paths before the current spec and evidence
updates; it has 1,079 now. The combined worktree affects the full-suite coverage totals. This
coverage slice changed `app/controllers/concerns/browser_rp_authentication.rb`, added
`test/middleware/credential_deletion_finalizer_test.rb` and
`test/models/client_contact_audit_outbox_test.rb`, and updated
`specs/test-coverage-completion/spec.md`. No schema, credentials, coverage threshold, exclusion,
source ignore annotation, CI configuration, commit, or push was changed in this slice. The CI
workflow is dirty from earlier work and was not edited here.

## Behavior and TDD

`adr/invalid-browser-credential-recovery.md` requires a confirmed invalid RP access-cookie refusal
to survive the exception response path. Before the implementation change, the focused
exception-response test returned the expected 404 but had no access-cookie deletion header. The
change now registers the already-decided deletion with `CredentialDeletionFinalizer` after the
normal Rails cookie-jar deletion is prepared. A request-level middleware test verifies that the
exception renderer's replacement response includes the access-cookie deletion and no refresh or
session-cookie deletion. Additional tests verify that an already-written replacement cookie is not
duplicated and a blank cookie name raises.

The preference audit API is tested as a public model contract for committed promotional and
notifiable changes, unchanged values, mismatched owners, and invocation outside the source
transaction. Source search still finds no application preference writer calling
`ClientContactAuditOutbox.record_preferences_changed!`; no preference UI or writer was invented.
That owner/workflow discrepancy remains open.

## Verification

| Command/check                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Result                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/middleware/credential_deletion_finalizer_test.rb test/models/client_contact_audit_outbox_test.rb test/integration/base_app_invalid_browser_rp_credential_test.rb test/controllers/concerns/browser_rp_authentication_test.rb` | Passed: **11 tests / 48 assertions / 0 failures / 0 errors / 0 skips**. The runtime catalog showed PostgreSQL 18.6.                                                                                                                                                           |
| `bin/rubocop app/controllers/concerns/browser_rp_authentication.rb test/middleware/credential_deletion_finalizer_test.rb test/models/client_contact_audit_outbox_test.rb`                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Passed: 3 files, 0 offenses.                                                                                                                                                                                                                                                  |
| `COVERAGE=true POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db RAILS_ENV=test bin/rails test`                                                                                                                                                                                                                                     | Minitest passed: **7,500 tests / 50,188 assertions / 0 failures / 0 errors / 0 skips**. SimpleCov then exited 2 on unchanged gates: line **90.42% (30,119/33,307; minimum 98%)**, branch **62.11% (3,506/5,644; minimum 93%)**, method **85.59% (4,339/5,069; minimum 97%)**. |
| Latest `bun run test:coverage`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | No JavaScript or TypeScript source changed after the verified result: 59 files / 588 tests; statements **100% (1,072/1,072)**, branches **100% (824/824)**, functions **100% (360/360)**, lines **100% (1,045/1,045)**.                                                       |

The two new public methods were covered in the full run. The updated method inventory was generated
from the current Rails runtime and combined SimpleCov results using
`SimpleCov::Combine::MethodsCombiner`.

| Visibility         |      Rows |   Reached | Uncovered | No one-to-one location | Same-line name mismatch |
| ------------------ | --------: | --------: | --------: | ---------------------: | ----------------------: |
| Public instance    |     1,603 |     1,344 |       105 |                    135 |                      19 |
| Public class       |       912 |       892 |        18 |                      0 |                       2 |
| Protected instance |        61 |        49 |        12 |                      0 |                       0 |
| **Total**          | **2,576** | **2,285** |   **135** |                **135** |                  **21** |

The two newly reached entries are `ClientContactAuditOutbox.record_preferences_changed!` and
`CredentialDeletionFinalizer.register`. The other 135 uncovered method identities match the
previously classified set in
[`2026-11-13-coverage-reachability-L6N2.md`](2026-11-13-coverage-reachability-L6N2.md): methods
blocked before their bodies by the unavailable Access boundary, maintenance/configuration
entrypoints, or methods with no current application caller. The 135 rows without a one-to-one
SimpleCov location and 21 source-line/name mismatches are mapping limits; they are not counted as
covered. The preference audit method has a passing public contract test but still no application
writer caller.

`git diff --check` passed. `scripts/check-repository-knowledge` passed for this record, the updated
coverage spec, and the current ordered-work-order evidence set: 8 Skills/adapters, 67 documents, and
4 evidence records. Credentials have no changed paths. No database schema was changed and no commit
or push was made.

## Disposition

Vitest's 100% result and the Minitest functional run are green. AC-2 remains below the unchanged
SimpleCov line, branch, and method gates. The current runtime method join closes two prior misses;
reachability dispositions for the remaining uncovered rows carry forward from L6N2. The absence of
an application preference-audit writer is an unresolved behavior-ownership discrepancy. This
coverage objective remains in progress.
