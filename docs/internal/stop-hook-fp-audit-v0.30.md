# Stop Hook False-Positive Audit — v0.30.0

**Date:** 2026-04-28
**Closes:** GitHub issue #71

This audit catalogs every code path in `hooks/stop-check.sh` and `hooks/completion-audit.sh` that can return a `block` decision and verifies each path either fires correctly or has a clear escape hatch. The four false-positive bug fixes shipped in v0.30.0 Phase 76 are the deliverable for this audit.

## Method

1. Read `hooks/stop-check.sh` and `hooks/completion-audit.sh` end-to-end.
2. Enumerate every block-emitting path.
3. For each path, document: the trigger, the user-visible message, and the escape hatch (how the user gets unstuck).
4. Cross-reference the open false-positive bug reports filed before this milestone (#85, #86, #87, #88).
5. Land regression tests for every category fixed; audit produces a documented "what's left" list.

## stop-check.sh — block paths

| # | Path / line | Trigger | Escape hatch | Status |
|---|---|---|---|---|
| 1 | Required-skills missing branch (~L338) | `state` file missing one or more skills in `required_planning` | Invoke the missing skill, or `~/.claude/.silver-bullet/trivial` for trivial sessions | ✅ Working as intended |
| 2 | Required-skills missing on `main` | Same, with on-main filter for `finishing-a-development-branch` | Same as #1 | ✅ |
| 3 | Pre-v0.30.0: full `required_deploy` enforcement | Stop hook applied milestone-ship list (deploy-checklist, create-release, etc.) at every conversation end | Manually invoke 8+ skills or set trivial flag | ✅ **Fixed in v0.30.0 #85** — Stop now applies `required_planning` floor only |
| 4 | Pre-v0.30.0: HOOK-14 over-catch on transient ignored files | `.claude/scheduled_tasks.lock`, `.claude/settings.local.json`, `.superpowers/**`, `REVIEW.md` made `tree_clean=false` | None — loop indefinitely | ✅ **Fixed in v0.30.0 #88** — transient-path allowlist with config override |
| 5 | Cross-branch stale state guard (~L257) | `branch` file does not match current branch | Hook fail-opens (no block) — this is intended | ✅ Designed correctly |
| 6 | Branch-file absent + dirty tree (Test 16) | Cannot validate branch scope, defaults to enforcement | Manually create branch file with `echo "$(git rev-parse --abbrev-ref HEAD)" > ~/.claude/.silver-bullet/branch` | ✅ Documented |
| 7 | Composed-workflow strict gate via SB_WORKFLOW_ID | (Not in stop-check; see completion-audit below) | n/a | n/a |

## completion-audit.sh — block paths

| # | Path | Trigger | Escape hatch | Status |
|---|---|---|---|---|
| 1 | Two-tier intermediate (`git commit`, `git push`) | Missing `required_planning` skills | Invoke the planning skill | ✅ |
| 2 | Two-tier final delivery (`gh pr create`, `gh release create`, `gh pr merge`, `deploy*`) | Missing `required_deploy` skills | Invoke each missing skill | ✅ |
| 3 | Strict SB_WORKFLOW_ID gate | `.planning/workflows/<id>.md` exists, command is delivery, but `SB_WORKFLOW_ID` unset OR malformed OR doesn't match a file OR matched file's Flow Log isn't 100% complete | Set/correct `SB_WORKFLOW_ID`; mark missing flows complete via `bash scripts/workflows.sh complete-flow <id> <flow>`; or remove stale workflow file via `complete <id>` | ✅ |
| 4 | Pre-v0.30.0: `count_complete_flow_rows` only matched `complete` | Workflows with legitimately-skipped flows (e.g. FLOW 8 UI QUALITY for CLI tools) blocked release | None — loop indefinitely | ✅ **Fixed in v0.30.0 #86** — `(complete\|skipped)` now counted as terminal |

## SessionStart — destructive-mutation paths

| # | Path | Trigger | Status |
|---|---|---|---|
| 1 | Pre-v0.30.0: every `compact` event stripped `gsd-*` markers | `/compact` mid-feature wiped GSD progress | ✅ **Fixed in v0.30.0 #87 Bug 1** — only `startup` and `clear` mutate state |
| 2 | Pre-v0.30.0: silent branch-file write failure | `printf > $branch_file` failed silently → first-run path fired every session | ✅ **Fixed in v0.30.0 #87 Bug 2** — write is now verified, warns on failure |
| 3 | Pre-v0.30.0: empty `current_branch` + non-empty `stored_branch` triggered wipe | Subagent CWD with detached HEAD or git failure caused state-file wipe | ✅ **Fixed in v0.30.0 #87 Bug 3** — branch-mismatch path requires both values non-empty |

## What's left after v0.30.0

The four headline FP categories filed against `stop-check.sh` and friends are eliminated. Remaining concerns that surface as Stop FPs but originate elsewhere:

- **Agent SDK / claude.ai/code runtime FPs (#48, #50):** Hooks don't fire in those runtimes. Documented in `silver-bullet.md §12` and `silver-bullet.md.base §11`. Cannot be fixed in SB code; upstream runtime change required.
- **Skill-recording race conditions across subagent boundaries:** No reliable repro filed. If observed, file a fresh issue with stdin payload + state-file-before-after capture.
- **Trivial-session detection edge cases:** `trivial_file` is honored when present and not a symlink. No reports against current implementation.

## Regression tests landed

- `tests/hooks/test-completion-audit.sh` — 3 new (`WF-PASS2-I/J/K`)
- `tests/hooks/test-stop-check.sh` — 6 new (`#88-A/B/C` and `#85-A/B/C`)
- `tests/hooks/test-session-start.sh` — 9 new (`#87-A/B/C/D` covering compact/resume/clear/empty-branch)

Total: 18 new regressions covering every fixed FP scenario.
