# Retained RP uniqueness

- Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`. Extensive pre-existing uncommitted changes
  and concurrent authorized remediation affected these results; this is not a clean-HEAD run.
- Scope: Base APP, Base ORG and Tech ORG callback-state models; Base APP/ORG actor selection models;
  Base ORG avatar selection. No other RP cells or schema definitions changed in this slice.
- Added exact unique validation for callback `state_digest` and selection `rp_session_id`.
  PostgreSQL unique indexes remain authoritative under validation bypass and concurrent writes.
- Writer inspection: `AcmeSelectableContext#persist_rp_app_selection!` and
  `#persist_rp_org_selection!` lock the owning session before selection lookup and mutation.
  ORG avatar selection is written under the same session lock. These writers contain no duplicate
  exception recovery that the added validation replaces; no writer changes were necessary.
- No runtime consumer of the three callback-state models was found in `app/` or `lib/`.
  Tests establish digest reservation after marking a row consumed, not a working callback protocol
  or atomic callback-consumption flow. The older OP OAuth callback models are different owners.
- Red: `bin/rails test test/models/rp_retained_uniqueness_test.rb`, PostgreSQL 18.6, seed 61590:
  4 runs, 4 assertions, 4 failures, 0 errors, 0 skips. Duplicate records passed model validation.
- Green and public-caller regression command:

  ```bash
  bin/rails test test/models/rp_retained_uniqueness_test.rb test/models/rp_base_session_selection_validation_test.rb test/models/rp_base_org_session_avatar_selection_test.rb test/controllers/base/app/rp_selector_flow_test.rb test/concurrency/base_selector_single_write_http_test.rb test/services/acme/selector_authority_test.rb
  ```

  Seed 19289: 19 runs, 148 assertions, 0 failures, 0 errors, 0 skips. Includes APP/ORG concurrent
  selector first-commit behavior, existing refusal paths and switcher updates.
- New tests cover per-cell digest isolation, consumed-row digest reservation, distinct states,
  selection scope, existing-row updates, conflicting session reassignment and direct PostgreSQL
  uniqueness rejection with validation disabled.
- Focused RuboCop: all six modified models plus the new test, 7 files inspected, no offenses.
- Initial Red attempt hit the repository's concurrent-test process lock before executing tests.
  A first Green launch failed before tests because of a transient syntax error in the coordinating
  locale change; after its owner fixed both locale files, the recorded Green run passed.
- Coverage and the full checker recheck belong to the coordinating aggregate run; no standalone
  coverage percentage or complete checker result is asserted here.
