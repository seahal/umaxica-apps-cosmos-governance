# Remaining foreign-key validation

Status: implementing — proposal preparation only. Validation implementation and execution await the new approval below.

## Authority and observed baseline

This child of [Governance database consistency](spec.md) records the proposed next schema slice after the owner retained all fifteen non-Queue Governance connections. The parent’s initial PENDING classifications predate that decision. Only the six KEEP writers below are affected; replicas follow their writer. Solid Queue, removed databases, CI, Models and data repair are outside this proposal.

Observed against `43db4906742db2fb13b238c9ccde378e4e1583b4` with substantial uncommitted work. The read-only PostgreSQL catalog came from the six fresh `test_gov_removal_20261112_t3_*` databases. It contains **98 existing unvalidated FKs across 54 tables**, no unvalidated CHECK in this slice. No validation migration has been run for these 98 constraints. A later read-only scan of the separate current test databases found zero orphan rows across all 98 named FKs; 96 were already validated there and the APP/ORG Signal FKs remained unvalidated. This does not establish the state of production or shared data, whose contents and load remain unverified. See `evidence/2026-11-12-database-consistency-baseline-D8K2.md`.

| Writer | Migration owner | FKs | Table units |
| --- | --- | ---: | ---: |
| `app_setting` | `db/app_settings_migrate` | 5 | 5 |
| `org_setting` | `db/org_settings_migrate` | 9 | 5 |
| `app_signal` | `db/app_signals_migrate` | 1 | 1 |
| `org_signal` | `db/org_signals_migrate` | 1 | 1 |
| `chronicle` | `db/chronicle_migrate` | 19 | 10 |
| `occurrence` | `db/occurrences_migrate` | 63 | 32 |

The FK names were reconciled to their declarations and rename history using exact local Rails name hashes or explicit names. Creation sources are the APP/ORG setting schema loaders, APP/ORG signal constructors, Chronicle schema loader and outbox action migration, and occurrence PK reconstruction/customer creation migrations. The remaining occurrence `visitor` constraints originated under `customer`; legacy `user_occurrence_id` and `staff_occurrence_id` columns remain unchanged.

`NOT VALID` is a legitimate staged rollout mechanism. No current durable decision was found requiring any listed FK to stay permanently unvalidated. Bootstrap flags and later NOT NULL CHECK validation do not prove FK validation. Historical Chronicle document/timeline tables remain retained audit data despite lacking runtime Models; their data must not be deleted or excluded. Their ownership and retention review precedes that execution slice.

## One scoped approval requested

Approve **all 98 exact validation-only changes in the manifest below**, including the monotonic rollback policy and scan/lock risks. The previous approval covered 42 other constraints; it does not establish approval of this new set. Following approval, unchanged table units do not require 54 repeated approval questions. A changed FK definition, data repair, wider scope or production/shared execution requires its own decision.

```text
Before: same named FOREIGN KEY (columns) REFERENCES local_parent (columns)
        with existing delete/update/deferral semantics, NOT VALID
After:  identical FK definition with historical rows validated
        pg_constraint.convalidated: false -> true
```

Names, columns, types, nullability, targets, actions, defaults, indexes, triggers and rows stay intact. The manifest contains 95 NO ACTION FKs, two existing signal CASCADE FKs, and one existing Chronicle outbox SET NULL FK. This approval does not introduce CASCADE or a cross-database FK.

## Execution and recovery contract

- Generate live migrations only after approval, through the exact owning `--database` generator. Append validation migrations; editing old history would not update existing migration receipts.
- Execute one table unit at a time; the two FKs on a child/pivot table share a transaction. Start with the two signal examples, then preference children, active Chronicle, historical Chronicle after ownership review, and occurrence tables. Grouping units needs a measured lock/scan budget.
- `up` calls named `validate_foreign_key` only. Missing constraints, orphaned historical rows, lock timeouts and other failures stop the unit. The transaction rolls back that unit’s validation changes; no invalid row is removed, rewritten or supplied a fabricated parent. Independent clean units may proceed.
- `down` raises `ActiveRecord::IrreversibleMigration` before DDL, preserving validated constraints. This is the same monotonic policy used by the earlier approved 42-constraint slice, but requires explicit approval for these new units because the generic migration rule normally requires reversibility. No drop/re-add downgrade, catalog modification or silent no-op rollback is proposed.
- Recovery is application-code rollback while retaining compatible, validated FKs and their migration receipts. Reconstruct only an independently identified disposable development/test database if the old unvalidated baseline is needed. Production/shared reconstruction or application is not authorized.
- Use only the selected writer’s scoped/versioned migration task. Do not invoke global migration/drop/prepare tasks, mutate Queue, suppress a checker, disable triggers or add broad safety acknowledgements.

Validation scans existing rows. It takes SHARE UPDATE EXCLUSIVE on the child and ROW SHARE on the referenced table; ordinary DML can continue while conflicting DDL/maintenance or I/O pressure remains a risk. Use finite lock timeouts and an observed per-table statement budget. Local reconstruction does not establish production load safety. [PostgreSQL 18 ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html).

## Acceptance and verification

- AC-1: On an independently prepared PostgreSQL baseline, assert the selected real FK metadata is unvalidated before the change, then validated afterward. Compare all definitions and unrelated metadata; only validation flags change. Enumerate the actual catalog independently of migration constants.
- AC-2: Direct SQL, `insert_all` and `update_all` exercise valid parents, missing parents (SQLSTATE 23503), existing nullable references and valid seeded zero IDs where the actual parent catalog permits them. Preserve the existing NO ACTION/CASCADE/SET NULL outcomes and retained audit rows.
- AC-3: In an isolated fixture schema built before adding the exact NOT VALID FK, seed an otherwise-valid historical orphan. The real migration must fail without deleting data, validating that FK or recording the migration as complete. For paired FKs, failure of the second rolls the first validation back. No shared constraint is disabled for fixture setup.
- AC-4: Real PostgreSQL concurrency verifies bounded lock-timeout recovery and continued FK enforcement for normal writes during validation. `down` refusal leaves metadata/data unchanged. Database construction is executed outside Minitest; behavior tests exercise the actual DB contract.
- AC-5: Run affected model/integration regressions, lint and appropriate coverage; separately rehearse empty reconstruction and existing-schema upgrade. Generate and compare the owning schema dumps after successful scoped application.
- AC-6: Run the standard unconfigured `RAILS_ENV=test bundle exec database_consistency`, preserve its real exit status and separate Queue findings. Ninety-eight validation flags are not ninety-eight checker warnings, and this slice alone does not establish overall consistency completion.

No acceptance criterion is verified yet. Draft bodies for the first two units are review examples under `tmp/original-consistency/proposed-migrations/`, not live migration files. The detailed read-only source/catalog inventory is `tmp/original-consistency/not-valid-fk-validation-plan.json`.

## Exact manifest

Each row is a table-level execution unit. References and names are listed in the same order; existing actions are described above.

### app_setting

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `app_preference_cookies` | `fk_rails_1e767a1c3f` | `preference_id -> app_preferences.id` |
| `app_preference_languages` | `fk_rails_74e24f1ed5` | `preference_id -> app_preferences.id` |
| `app_preference_regions` | `fk_rails_ebeda50e04` | `preference_id -> app_preferences.id` |
| `app_preference_themes` | `fk_rails_b65e40e97b` | `preference_id -> app_preferences.id` |
| `app_preference_timezones` | `fk_rails_3a83164d61` | `preference_id -> app_preferences.id` |

### org_setting

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `org_preference_cookies` | `fk_rails_73a85808d0` | `preference_id -> org_preferences.id` |
| `org_preference_languages` | `fk_org_preference_languages_on_option_id`<br>`fk_rails_1a77b3c035` | `option_id -> org_preference_language_options.id`<br>`preference_id -> org_preferences.id` |
| `org_preference_regions` | `fk_org_preference_regions_on_option_id`<br>`fk_rails_42f3316029` | `option_id -> org_preference_region_options.id`<br>`preference_id -> org_preferences.id` |
| `org_preference_themes` | `fk_org_preference_themes_on_option_id`<br>`fk_rails_eee86b08b3` | `option_id -> org_preference_theme_options.id`<br>`preference_id -> org_preferences.id` |
| `org_preference_timezones` | `fk_org_preference_timezones_on_option_id`<br>`fk_rails_97d21cd824` | `option_id -> org_preference_timezone_options.id`<br>`preference_id -> org_preferences.id` |

### app_signal

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `member_notifications` | `fk_rails_1491caec8a` | `user_notification_id -> client_notification_records.id` |

### org_signal

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `operator_notifications` | `fk_rails_18cd968454` | `staff_notification_id -> operator_notification_records.id` |

### chronicle

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `app_document_audits` | `fk_rails_04199ae3cc`<br>`fk_rails_a9e9b70220` | `event_id -> app_document_audit_events.id`<br>`level_id -> app_document_audit_levels.id` |
| `app_preference_chronicles` | `fk_rails_d693b46c45`<br>`fk_rails_da47dd8941` | `event_id -> app_preference_chronicle_events.id`<br>`level_id -> app_preference_chronicle_levels.id` |
| `app_timeline_audits` | `fk_rails_2babaf0d7d`<br>`fk_rails_b95cff528f` | `event_id -> app_timeline_audit_events.id`<br>`level_id -> app_timeline_audit_levels.id` |
| `chronicle_outbox_entries` | `fk_rails_6a19517853` | `chronicle_id -> chronicles.id` |
| `client_chronicles` | `fk_rails_829f1830de`<br>`fk_rails_868bedb021` | `event_id -> client_chronicle_events.id`<br>`level_id -> client_chronicle_levels.id` |
| `com_preference_chronicles` | `fk_rails_592279f49b`<br>`fk_rails_c194bd8de2` | `level_id -> com_preference_chronicle_levels.id`<br>`event_id -> com_preference_chronicle_events.id` |
| `operator_chronicles` | `fk_rails_46a8075569`<br>`fk_rails_f0451c267b` | `level_id -> operator_chronicle_levels.id`<br>`event_id -> operator_chronicle_events.id` |
| `org_document_audits` | `fk_rails_46d3b866ce`<br>`fk_rails_ed52fec6a9` | `event_id -> org_document_audit_events.id`<br>`level_id -> org_document_audit_levels.id` |
| `org_preference_chronicles` | `fk_rails_3829eb3d72`<br>`fk_rails_f932dbadd7` | `event_id -> org_preference_chronicle_events.id`<br>`level_id -> org_preference_chronicle_levels.id` |
| `org_timeline_audits` | `fk_rails_1c8eb96fbb`<br>`fk_rails_eae8a241e3` | `level_id -> org_timeline_audit_levels.id`<br>`event_id -> org_timeline_audit_events.id` |

### occurrence

| Child table | Exact constraint names | Existing references |
| --- | --- | --- |
| `area_client_occurrences` | `fk_rails_bc8f2fb1d9`<br>`fk_rails_f171bdb1c9` | `area_occurrence_id -> area_occurrences.id`<br>`user_occurrence_id -> client_occurrences.id` |
| `area_domain_occurrences` | `fk_rails_5bec914d67`<br>`fk_rails_8684e941ea` | `area_occurrence_id -> area_occurrences.id`<br>`domain_occurrence_id -> domain_occurrences.id` |
| `area_email_occurrences` | `fk_rails_587a294924`<br>`fk_rails_a358e72324` | `email_occurrence_id -> email_occurrences.id`<br>`area_occurrence_id -> area_occurrences.id` |
| `area_ip_occurrences` | `fk_rails_02206200a2`<br>`fk_rails_22b982fb0e` | `ip_occurrence_id -> ip_occurrences.id`<br>`area_occurrence_id -> area_occurrences.id` |
| `area_operator_occurrences` | `fk_rails_51d4f8ec16`<br>`fk_rails_e851adb93d` | `area_occurrence_id -> area_occurrences.id`<br>`staff_occurrence_id -> operator_occurrences.id` |
| `area_telephone_occurrences` | `fk_rails_42743b1b5d`<br>`fk_rails_58c6f190f9` | `telephone_occurrence_id -> telephone_occurrences.id`<br>`area_occurrence_id -> area_occurrences.id` |
| `area_visitor_occurrences` | `fk_rails_22c72f835b`<br>`fk_rails_cb6a0677f8` | `area_occurrence_id -> area_occurrences.id`<br>`visitor_occurrence_id -> visitor_occurrences.id` |
| `area_zip_occurrences` | `fk_rails_18554dc64e`<br>`fk_rails_2f56574cee` | `area_occurrence_id -> area_occurrences.id`<br>`zip_occurrence_id -> zip_occurrences.id` |
| `client_zip_occurrences` | `fk_rails_3e61e47523`<br>`fk_rails_c91ad2be3e` | `user_occurrence_id -> client_occurrences.id`<br>`zip_occurrence_id -> zip_occurrences.id` |
| `domain_client_occurrences` | `fk_rails_5fc25fbd6a`<br>`fk_rails_cc055fd395` | `user_occurrence_id -> client_occurrences.id`<br>`domain_occurrence_id -> domain_occurrences.id` |
| `domain_email_occurrences` | `fk_rails_190d1d7227`<br>`fk_rails_dfecbcc166` | `email_occurrence_id -> email_occurrences.id`<br>`domain_occurrence_id -> domain_occurrences.id` |
| `domain_ip_occurrences` | `fk_rails_30c617346d`<br>`fk_rails_77c6097609` | `ip_occurrence_id -> ip_occurrences.id`<br>`domain_occurrence_id -> domain_occurrences.id` |
| `domain_operator_occurrences` | `fk_rails_93a08a87ce`<br>`fk_rails_a39158f9e1` | `domain_occurrence_id -> domain_occurrences.id`<br>`staff_occurrence_id -> operator_occurrences.id` |
| `domain_telephone_occurrences` | `fk_rails_43b450d653`<br>`fk_rails_fc2f6167c7` | `domain_occurrence_id -> domain_occurrences.id`<br>`telephone_occurrence_id -> telephone_occurrences.id` |
| `domain_zip_occurrences` | `fk_rails_20ab26995d`<br>`fk_rails_f15deee84c` | `zip_occurrence_id -> zip_occurrences.id`<br>`domain_occurrence_id -> domain_occurrences.id` |
| `email_client_occurrences` | `fk_rails_64273fb6e5`<br>`fk_rails_7a5ab1e241` | `email_occurrence_id -> email_occurrences.id`<br>`user_occurrence_id -> client_occurrences.id` |
| `email_ip_occurrences` | `fk_rails_b2fd16e596`<br>`fk_rails_cc0f42ece0` | `email_occurrence_id -> email_occurrences.id`<br>`ip_occurrence_id -> ip_occurrences.id` |
| `email_operator_occurrences` | `fk_rails_1b3f55514c`<br>`fk_rails_59212c3511` | `email_occurrence_id -> email_occurrences.id`<br>`staff_occurrence_id -> operator_occurrences.id` |
| `email_telephone_occurrences` | `fk_rails_209d51cbd3`<br>`fk_rails_34a4ac5d57` | `telephone_occurrence_id -> telephone_occurrences.id`<br>`email_occurrence_id -> email_occurrences.id` |
| `email_visitor_occurrences` | `fk_rails_363c71b53f`<br>`fk_rails_c912bd4a94` | `email_occurrence_id -> email_occurrences.id`<br>`visitor_occurrence_id -> visitor_occurrences.id` |
| `email_zip_occurrences` | `fk_rails_381f0f5f60`<br>`fk_rails_c31148b25f` | `zip_occurrence_id -> zip_occurrences.id`<br>`email_occurrence_id -> email_occurrences.id` |
| `ip_client_occurrences` | `fk_rails_00e504b9ab`<br>`fk_rails_72d1905cdd` | `user_occurrence_id -> client_occurrences.id`<br>`ip_occurrence_id -> ip_occurrences.id` |
| `ip_operator_occurrences` | `fk_rails_6d03a3d401`<br>`fk_rails_f098ca3601` | `staff_occurrence_id -> operator_occurrences.id`<br>`ip_occurrence_id -> ip_occurrences.id` |
| `ip_telephone_occurrences` | `fk_rails_0091298830`<br>`fk_rails_6a0a2e9960` | `ip_occurrence_id -> ip_occurrences.id`<br>`telephone_occurrence_id -> telephone_occurrences.id` |
| `ip_visitor_occurrences` | `fk_rails_008a174aa0`<br>`fk_rails_4bd9e2f547` | `visitor_occurrence_id -> visitor_occurrences.id`<br>`ip_occurrence_id -> ip_occurrences.id` |
| `ip_zip_occurrences` | `fk_rails_43681b033b`<br>`fk_rails_9136c2236a` | `ip_occurrence_id -> ip_occurrences.id`<br>`zip_occurrence_id -> zip_occurrences.id` |
| `operator_client_occurrences` | `fk_rails_13800338d1`<br>`fk_rails_1e7954599d` | `user_occurrence_id -> client_occurrences.id`<br>`staff_occurrence_id -> operator_occurrences.id` |
| `operator_telephone_occurrences` | `fk_rails_4fe85fb8ea`<br>`fk_rails_8b1f6ba670` | `staff_occurrence_id -> operator_occurrences.id`<br>`telephone_occurrence_id -> telephone_occurrences.id` |
| `operator_zip_occurrences` | `fk_rails_69f99bbeaf`<br>`fk_rails_b2a9b8a8b3` | `staff_occurrence_id -> operator_occurrences.id`<br>`zip_occurrence_id -> zip_occurrences.id` |
| `telephone_client_occurrences` | `fk_rails_6f536d5ebf`<br>`fk_rails_e92d26d9f1` | `user_occurrence_id -> client_occurrences.id`<br>`telephone_occurrence_id -> telephone_occurrences.id` |
| `telephone_zip_occurrences` | `fk_rails_762eceb883`<br>`fk_rails_79d04c2147` | `zip_occurrence_id -> zip_occurrences.id`<br>`telephone_occurrence_id -> telephone_occurrences.id` |
| `visitor_occurrences` | `fk_rails_f0316e1852` | `status_id -> visitor_occurrence_statuses.id` |

## Governing material

- Accepted DB-invariant and local-reference contracts: `adr/authority-lifecycle-table-policy.md`, `adr/cross-db-reference-policy.md`, `adr/chronicle-audit-db-consolidation.md`.
- Naming and staged validation evidence: `adr/surface-database-connection-naming.md`, `docs/checklists/identifier-contracts.md`. Historical preference ADR fragments and old Publishing scope do not override the latest owner classification.
- Implementation rules: `.agents/harnesses/rules/generic/migrations.mdc` and `generic/data-shape-design.mdc`. This proposal exposes the rollback-rule exception for approval rather than assuming it.
