# CONTEXT — v0.39.1 patch (scan + receipt persistence)

**Scope:** Close HANDOFF_v2 `#221` investigation, ship unreleased `ab12e86` scan fix, cut `v0.39.1`.

## Locked decisions

- **Receipt root cause:** Codex adapter writes to `~/.codex/.silver-bullet/skill-invocations`; repo-source hooks auto-detected Claude runtime and searched `~/.codex/…`, so desktop `exec_command` receipts were invisible to `record-skill`.
- **Fix approach:** Cross-runtime receipt dir search via `sb_runtime_skill_receipt_dirs()`; also treat `CLAUDE_PLUGIN_ROOT` under `/.codex/` as codex runtime.
- **Release scope:** Patch only — `#221` fix + `ab12e86` scan discovery; do not bundle `#217` (release-body validation still open).

## Constraints

- `#217` remains open; generic GitHub Release body validation is out of scope for this patch.
- Kay exec fixes already committed upstream (`992ac6bbf7`).
- Preserve untracked `.kay/` and `.planning/debug/quality-gates-route-smoke-timeout.md`.

## Assumptions

| Assumption | Status | Owner |
|------------|--------|-------|
| Installed Codex 0.39.0 hooks already work when both adapter and hook live under `~/.codex/` | Accepted | SB |
| Repo dogfooding (repo hooks + Codex adapter) is the failure mode this patch fixes | Accepted | SB |
| CI for `ab12e86` is green (run 27469250436) | Accepted | prior session |

## Open questions

- None blocking release. `#217` deferred to follow-up patch.

## Planning handoff

**In scope:** Commit `#221` fix; run verify-tests + release gate; publish `v0.39.1` with changelog; close `#221`.

**Out of scope:** `#217` enforcement, planning STATE/ROADMAP refresh for v0.39.x milestone narrative.

**Acceptance:** `test-record-skill.sh` green; receipt probe passes; tag + GitHub Release published.
