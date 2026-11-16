# Zenith width and reference-index rehearsal

- Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`. Extensive uncommitted changes, including
  the three coordinating migrations below, affected this run. No migration source was edited by
  this verification unit.
- Targets were only receipt-owned `test_dbc_20261112_governance_app_zenith` and
  `test_dbc_20261112_governance_org_zenith`, verified against
  `tmp/keep-reconstruction/results.json`, the actual pool identity and
  `Umaxica::TestEnvironment::DatabaseSafety`. No top-level test, development, production, shared
  provider or Solid Queue database was changed.

## Source and Red metadata

| Version | Source owner | SHA-256 |
| --- | --- | --- |
| 20261112120929 | app_principals_migrate / ExpandRegistrationCompletionIdentifierWidth | dfaf5bb88b771dafefde366a3e5e83bb6e76f08aba84db7347b0a11c4934e1ff |
| 20261112120932 | app_principals_migrate / IndexRetainedAppZenithReferences | 6d5a89b84dedc94f2b264463c6422bdf610532ab78b1209bfee7d94ac94a6abc |
| 20261112120934 | org_principals_migrate / IndexRetainedOrgZenithReferences | 6a8b130e8a0848e89d44757190d647920163800b66cfd0d0131be480b6f700be |

Standalone `RAILS_ENV=test bin/rails runner tmp/diagnose_zenith_proposals.rb` confirmed both
`client_registration_completion_methods.id` and `client_registration_completions.method_id` were
`int2`, and all five approved indexes were absent. This was an operational metadata observation,
not an environment-construction Minitest test. Result:
`tmp/keep-reconstruction/zenith-proposals-red.json`.

## Existing-schema rehearsal

`RAILS_ENV=test bin/rails runner tmp/rehearse_zenith_proposals.rb` executed each exact version
up/down/up using its official pool migration context, without rolling back older migrations.
The runner's SHA-256 was `05338184f0fa0bfec18ea76c33806bb98e28b6d50925e34b931bce88ef7a54cf`.

Before migration it inserted four legal diagnostic clients and registration-completion receipts in
the isolated APP database, one for each existing method ID 1, 2, 3 and 4. The fixture transaction
used direct parameterized DML and actual seeded prerequisite rows. SHA-256 snapshots of all
128 APP and 110 ORG application-table row sets remained equal after every phase. All existing
FK, CHECK, primary-key, unique and NOT NULL constraint definitions, validation/deferral flags and
existing index definitions remained equal. Index changes were limited to the approved additions;
rollback removed exactly those additions.

| Version | Up seconds | Down seconds | Second up seconds |
| --- | ---: | ---: | ---: |
| 20261112120929 | 0.0483 | 0.0397 | 0.0407 |
| 20261112120932 | 0.0405 | 0.0440 | 0.0401 |
| 20261112120934 | 0.0292 | 0.0276 | 0.0289 |

The width migration changed both columns to `int8` / NOT NULL, down restored both to `int2` /
NOT NULL with all four referenced values preserved, and the second up restored `int8`. At every
APP phase, IDs 0 and 5 were rejected by `chk_client_registration_completion_methods`; assigning
method 5 to an existing completion was rejected by `fk_rails_cc76c55eef`. The fixed method catalog
remained exactly email=1, telephone=2, google=3, apple=4. Its existing UNIQUE and CHECK definitions
were not relaxed. Final pending-migration lists were empty for both isolated databases.

`EXPLAIN` with sequential scans disabled used each new index for its corresponding equality
predicate. This demonstrates planner eligibility on tiny local data, not a production performance
estimate. Details: `tmp/keep-reconstruction/zenith-proposals-rehearsal.json`.

## Final read-only inspection

`RAILS_ENV=test bin/rails runner tmp/verify_zenith_proposals.rb` checked the final catalogs in
read-only transactions. All five indexes were `indisvalid=true`, `indisready=true`, and nonunique:

- `index_client_preferences_on_status_id`
- `index_client_retention_holds_on_status_id`
- `index_client_privacy_requests_on_status_id`
- `index_client_registration_completions_on_method_id`
- `index_operator_preferences_on_status_id`

The four isolated APP completion fixtures still existed, exactly one per method ID. Metadata:
`tmp/keep-reconstruction/zenith-proposals-final-catalog.json`.

All three runner commands exited 0. No Minitest tests, generator, source migrations, global test
setup, CI or final dumps were changed by this unit. Normal target application, fresh complete
reconstruction, generated dumps, drift checks, behavior regressions and aggregate checker/coverage
remain the coordinating agent's work. Local timings do not establish production rewrite or index
build duration, capacity, or lock contention.
