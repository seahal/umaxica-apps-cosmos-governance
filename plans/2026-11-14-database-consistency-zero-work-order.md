Task (umaxica-apps-cosmos-governance only): bring `database_consistency` to zero findings.

## Observed on 2026-11-14 (RAILS_ENV=test, exit 1, 1 finding)

`UniqueIndexChecker`: `OperatorChronicle` index `uniq_operator_chronicles_sign_flow_halted` is
unique in the database but has no uniqueness validator. It is the same finding recorded in
`evidence/2026-11-13-database-consistency-post-test-rebuild-F7K2.md`, where a diagnostic test showed
the checker returning `:fail` for the existing index.

## Work

Find why the checker does not recognise the validator (partial index condition, column order, scope
or case sensitivity), and make the validator state the index exactly. If the checker cannot express
the partial condition, record that with the gem version and the exact checker source line, and
propose options (validator shape the checker understands, or a database-side expression the model
can mirror) without adding an exclusion. Also report: is this chronicle still owned by Governance
after the split, or does the `sign_flow_halted` event belong to Access only?

No commit. Never print secrets, key material or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside this
repository. Do not disable a checker, add an exclusion or a todo file, or weaken a database
constraint to make the report pass; fix the model or the schema so both sides state the same
contract. Every schema change is a reversible migration. Tests Red first; no mocked behaviour under
test.

## Checks and report

`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` must exit 0 (record the
command and the finding count before and after). Then bin/rails zeitwerk:check, bin/rubocop,
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, the changed and related tests,
bin/rails test (separate pre-existing failures; unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its
stale list blocks boot and report it). Update docs/mermaid inventories and checklists if a lifecycle
or deletion rule changes.

Evidence: `evidence/YYYY-MM-DD-database-consistency-zero-XXXX.md` (full `git rev-parse HEAD`;
uncommitted changes affected results): each finding, its cause, the fix and its test, migrations,
results, owner items, and confirmation that config/credentials files are unchanged.
