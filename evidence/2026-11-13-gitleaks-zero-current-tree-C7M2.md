# Current-Tree Gitleaks Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree already contained 1,103 changed or untracked paths before this item. This record
describes that worktree, including those pre-existing changes. No commit, push, history rewrite,
credential, Rails credentials, or `.github/` file was changed. No production or shared service was
used.

## Scan method and result

The no-allowlist scan copied tracked and unignored current worktree files into a temporary snapshot
outside the repository and used the generated default Gitleaks configuration, which has no allowlist
section. The repository's existing `.gitleaks.toml` contains one allowlist; it was not changed or
used for this result. The referenced public Press evidence file was unavailable through the
read-only GitHub fetch, so the explicit transformations in this work order were applied directly.

| Check                                                                        |                    Before |                   After |
| ---------------------------------------------------------------------------- | ------------------------: | ----------------------: |
| Gitleaks default rules, current tracked and unignored worktree, no allowlist | 8,136 files; 118 findings | 8,136 files; 3 findings |
| `git diff --check`                                                           |     Not run for this item |                  Passed |

Command used for the after scan:

```text
gitleaks detect --no-git --source <temporary-current-tree-snapshot> --config tmp/ci-static-default-gitleaks.toml --redact --report-format json --report-path <temporary-redacted-report> --exit-code 0
```

No match values or environment values were printed or retained in this evidence. The temporary
snapshot and redacted report were outside the repository. The after-scan findings are:

- `.github/workflows/ci.yml:392`
- `.github/workflows/ci.yml:675`
- `compose.yaml:50`

## Finding disposition

- `research/2026-10-22-test-value-audit/duplicates.md`: relabeled all 107 `Body token hash` entries
  as `Source-body SHA-256 digest`. A before/after value comparison confirmed all 107 digest values
  were preserved exactly. These are source-body digests, not credentials.
- `plans/archive/0003-authentication-handoff-work-logs/zero-agent-message-board.md`: shortened all
  161 full commit IDs to their unique 12-character prefixes. Each prefix was unique in the local Git
  object database. No Git history was rewritten. The two scan findings in this file were removed; no
  full commit IDs remain there.
- `evidence/2026-09-15-e0-test-environment.md:34`: a worker-count setting and a non-authentication
  test run namespace. Environment assignment values were replaced with redaction markers.
- `evidence/2026-09-17-otp-consumption-lock.md:33`: local test Redis endpoint settings without URL
  user information and a non-authentication run namespace. Environment assignment values were
  replaced with redaction markers.
- `evidence/2026-09-17-otp-resend-lock.md:27`: local test Redis endpoint settings without URL user
  information and a non-authentication run namespace. Environment assignment values were replaced
  with redaction markers.
- `evidence/2026-09-18-jwt-anomaly-catalog-audit.md:53`, `:56`, and `:62`: test-environment, local
  test PostgreSQL/Valkey endpoint, and run-namespace settings; the Redis URLs contained no user
  information. Environment assignment values were replaced with redaction markers.
- `compose.yaml:50`: a public Valkey container image reference. Gitleaks classifies the image-name
  text as a generic API key; it contains no credential. Removing the redundant Docker Hub prefix did
  not change the finding, so the original image reference was retained.
- The two remaining workflow locations are reported above by file and line only. `.github/` was
  outside the authorized edit scope and was left unchanged.

No real credential was identified in the 118 findings. The current-tree zero-finding goal is not
met: three non-credential findings remain, including the two protected workflow locations and the
Compose image false positive. No allowlist, suppression, exclusion, or checker configuration change
was introduced.

## Worktree and verification limits

The worktree contained 1,109 changed or untracked paths after these edits and remains uncommitted.
No Rails or JavaScript tests were run for this documentation and historical-evidence cleanup. Docker
Compose was unavailable, so Compose resolution was not executed. No environment values were read
from process configuration or written to this record.
