# Governance unused environment variable cleanup

Date: 2026-11-10
HEAD: `43db4906742db2fb13b238c9ccde378e4e1583b4`
Scope: the owner's 22 expanded candidate names in this repository only. Extensive pre-existing
uncommitted changes affected the inspected worktree and were preserved. No credentials were
opened or modified; no destructive command, service restart or commit was performed.

## Removed locally: 13 names

- `PRIVATE_GUID_SERVICE_URL`
- `PRIVATE_PALM_SERVICE_URL`
- `PRIVATE_VISA_CORPORATE_URL`
- `PRIVATE_VISA_SERVICE_URL`
- `PRIVATE_VISA_STAFF_URL`
- `PUBLIC_DOCS_CORPORATE_URL`
- `PUBLIC_DOCS_SERVICE_URL`
- `PUBLIC_DOCS_STAFF_URL`
- `PUBLIC_GUID_SERVICE_URL`
- `PUBLIC_INFO_CORPORATE_URL`
- `PUBLIC_INFO_SERVICE_URL`
- `PUBLIC_INFO_STAFF_URL`
- `PUBLIC_STATUS_URL`

Deleted 13 matching assignment lines from `.env.container.devcontainer`, nine from `.env` and
eight from `.env.local`: 30 definitions total. Only matching assignment lines were removed;
nonmatching lines were preserved byte-for-byte. No additional definitions appeared in the inspected
Compose files or environment templates. Removed stale GUID variable setup instructions from
`docs/architecture/guid-surface.md` and the status-variable reference from
`docs/reference/ui-view-inventory.md`, preserving other content. No candidate references remained
in README/current docs after cleanup. Historical evidence/research were not rewritten.

## Kept with readers: nine names

| Name | Reader in the current worktree |
| --- | --- |
| `PRIVATE_AUTH_CORPORATE_URL` | Test-only selection at `test/test_helper.rb:275`, dynamic fetch at `:280`. The helper has no literal callers; retained conservatively because the reader remains. |
| `PRIVATE_HELP_SERVICE_URL` | `lib/config_values_host_family_values.rb:136`, name constructed at `:189`, fetched at `:249`. |
| `PRIVATE_HELP_CORPORATE_URL` | Same reader, selection at `:137`. |
| `PRIVATE_HELP_STAFF_URL` | Same reader, selection at `:138`. |
| `PRIVATE_INFO_SERVICE_URL` | `lib/config_values_host_family_values.rb:139`, name constructed at `:194`, fetched at `:249`. |
| `PRIVATE_INFO_CORPORATE_URL` | Same reader, selection at `:140`. |
| `PRIVATE_INFO_STAFF_URL` | Same reader, selection at `:141`. |
| `PUBLIC_CORE_CORPORATE_URL` | `lib/config_values_host_family_values.rb:118`, name selected at `:237–238`, fetched at `:249`. |
| `PUBLIC_WARP_CORPORATE_URL` | `lib/config_values_host_family_values.rb:132`, name constructed at `:211`, fetched at `:249`. |

The eight runtime inputs also have host-family tests. `PUBLIC_INFO_SERVICE_URL` occurs in the
negative/isolation test at `test/lib/config_values/host_family_values_test.rb:228`; assertions at
`:232–233` confirm the private input remains authoritative. It is not a required configuration
input. No test source was changed. All explicitly protected variables were left intact.

## Search and dynamic-name verification

Exact-name searches covered app/, lib/, config/ (excluding credentials), bin/, db/, src/, Rakefile,
Gemfile, package.json, vite.config.*, Procfile*, Containerfile*, podman/, .devcontainer/, .github/
and test/, including config/ci.rb. Absent paths such as script/ were checked for existence.
Definitions/templates, README and docs/runbooks were searched separately. An independent read-only
audit checked constructed names, variable-based ENV/creds lookups and broad ENV filters.

Visa selects `VISA_*` or `PUBLIC_VISA_*` (`lib/config_values_host_family_values.rb:201–205`);
Docs explicitly uses `PRIVATE_DOCS_*` (`:148–150`); Palm selects public/unprefixed service names
(`:181–183`). The finite development Host Authorization key list consumed at
`config/environments/development.rb:234` contains none of the 13 removed names. JWT ENV-key filters
match private-key suffixes rather than URL names. Dynamic credential lookups use finite provider,
Turnstile/encryption names or the OIDC client-secret namespace, none of these URL candidates.
Generic environment loading/snapshotting does not establish a specific runtime consumer.

## Checks and unexpected limits

- Confirmed zero removed-name definitions remain in the three edited environment files, using
  name-prefix inspection only. Scoped `git diff --check` passed.
- No Ruby or test file changed in this task; conditional RuboCop and Rails test runs were not needed.
- Requested `docker compose -f .devcontainer/compose.yaml config -q`: **blocked**, exit 127,
  because Docker is not installed. No Podman/Compose substitute was available.
- Fallback syntax check: Python `yaml.safe_load` successfully parsed `.devcontainer/compose.yaml`,
  `compose.yaml` and `compose.override.yaml`. This is YAML syntax evidence, not Compose validation.
- `.github` remains mounted read-only. **18 CI definitions remain**, two each for
  `PRIVATE_PALM_SERVICE_URL`, all three `PUBLIC_DOCS_*_URL`, all three `PUBLIC_INFO_*_URL`,
  `PUBLIC_GUID_SERVICE_URL` and `PUBLIC_STATUS_URL`. They are unused but could not be removed from
  this executor. No mount restriction was bypassed; global definition cleanup is incomplete.
