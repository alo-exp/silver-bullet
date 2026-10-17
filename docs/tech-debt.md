# Technical Debt Register

Format: `| Item | Severity | Effort | Status |`. Priority score = (Impact + Risk) × (6 − Effort), where Impact/Risk/Effort are 1–5. Resolved items stay listed with how they were resolved; the product backlog is [issues/BACKLOG.md](issues/BACKLOG.md).

---

## Open

| Item | Severity | Effort | Status |
|------|----------|--------|--------|
| `hooks/rfl-policy-c-gate.sh` runs under `set -euo pipefail` with no `ERR` trap, unlike the other hooks; an unexpected failure exits non-zero and surfaces as a hook error instead of failing open | Low | Low | Open (found 2026-10-17) |
| Without `jq`, `hooks/completion-audit.sh` blocks `git commit`, `git push`, `gh pr create`, `gh release create` and deploy commands even outside an SB project (its jq fallback runs before the project-activation check), contradicting "enforcement engages only in initiated projects" | Medium | Low | Open (found 2026-10-17) |
| The release-gate message for an incomplete SENTINEL manifest in `hooks/lib/completion-audit/deploy-tier.sh` hard-codes "85/85 clean rows"; the canonical skill count is now derived from `skills/*/SKILL.md` | Low | Low | Open (found 2026-10-17) |
| `scripts/install-claude.sh` falls back to a maintainer-specific absolute path for the `claude` binary when it is not on `PATH` | Low | Low | Open (found 2026-10-17) |
| `multi_agent.delegation_timeout_seconds` is in the config template and described in `docs/multi-agent-coordination.md`, but no script reads it | Low | Low | Open (found 2026-10-17) |
| `skills/silver-create-release` generates release notes with `##` section headings and inserts them under the `## [X.Y.Z]` heading of `CHANGELOG.md`, so each release reintroduces same-level subsections (normalized to `###` on 2026-10-17) | Low | Low | Open (found 2026-10-17) |
| `docs/workflows/` and `templates/workflows/` must stay byte-identical by hand; only tests catch drift | Low | Medium | Open |

## Resolved

| Item | Resolution |
|------|------------|
| CI step "Assert DEFAULT_REQUIRED is subset of DEFAULT_TRACKED" compared two empty strings (neither literal list existed any more), so it always passed | Replaced by the `required-subset-tracked` check in `scripts/check-repo-invariants.sh`, which checks every `required_*` list against `all_tracked` in the template and `.silver-bullet.json`; `tests/scripts/test-check-repo-invariants.sh` proves it fails on drift |
| `required_deploy` / `all_tracked` correctness not validated in CI (priority 1, score 35) | CI asserts `required_deploy` ⊆ `all_tracked` and that `.silver-bullet.json` skill lists match the template |
| No CI step enforcing `docs/workflows/` ↔ `templates/workflows/` parity (priority 2, score 30) | CI step "Check docs/workflows/ parity with templates/workflows/"; also `tests/docs/test-documentation-scheme.sh` |
| `hooks/dev-cycle-check.sh` had no test file (priority 3, score 24) | `tests/hooks/test-dev-cycle-check.sh` covers stages A–D, phase-skip detection, the trivial marker, state tamper, plugin boundary and devops-cycle |

## Partly resolved

| Item | Status |
|------|--------|
| `finalization_skills` in `dev-cycle-check.sh` was a hard-coded string that had to be kept in sync with `required_deploy` (priority 4, score 18) | The hook now derives the list from the project's `required_deploy` minus the lifecycle markers. A hard-coded fallback (`silver-branch-finish silver-create-release silver-completion-audit tdd`) and the lifecycle exclusion list remain in the script and still need manual upkeep when lifecycle skills change |
