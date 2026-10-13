# Round 6 — Full Operational Addendum (mandatory)

**Companion:** [ROUND-6-SESSION-HANDOFF.md](./ROUND-6-SESSION-HANDOFF.md)

**Parallel host tracks:** [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) · [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

Read first:

- `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-6-SESSION-HANDOFF.md`
- `/Users/shafqat/projects/silver-bullet/repo/docs/testing/ENTERPRISE-E2E-LIVE-TEST.md`
- `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md`
- `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`

## A. Mission & workspace

- **Session workspace root:** `/Users/shafqat/projects/silver-bullet/repo` (NOT test app, NOT Cursor global).
- **Claude TUI CWD:** `/Users/shafqat/projects/enterprise-grade-test-app`.
- **Goal:** **2 consecutive strict-clean rounds** for release (Round 5 done; Round 6 in progress).
- **Strict-clean** = ALL of:
  1. review-fix-ladder **8/8** with **2 consecutive clean verify passes per rung**, **0 new issues**
  2. live matrix **22/22** evidence PASS, **0 new friction/issues** vs baseline
  3. **every row** passes `enterprise_e2e_outcome_row_passes` (no `partial`)
  4. blocking autonomy gates pass: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
  5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85
- Evidence-only PASS or SKIP rows **do not** count strict-clean.

## B. Parent orchestrator behavior (this chat)

- Run **ONE** long-lived background worker (`Task`, `run_in_background: true`, **`model: composer-2.5` ONLY** — never `composer-2.5-fast`).
- **Resume the same worker ID** across turns; do not spawn parallel matrix operators.
- Relay **every poll cycle (~60–90s)** to this chat — substantive checkpoint, NOT "still running" and NOT only every 5 cycles.
- On row complete: evidence + full outcome checklist + friction summary + fix SHA if any.
- **Never pause for operator.** On blockers: diagnose → fix → re-run affected row yourself.
- If user explicitly requests pause: finish current poll turn, write checkpoint, then stop.

## C. Continuous TUI friction monitoring (active)

Worker must read **during** each row, not only at row end:

- `.e2e-rowN-attempt.log`, `.e2e-matrix-{host}-live.log` (e.g. `.e2e-matrix-round6-force.log` for Claude), monitor status, expect transcript
- Watch for: 0-token turns, MCP auth banners, stop-hook loops, picker/regex/Tcl `(?s)` failures, install-claude/PTY hangs, orchestrator parent bash deny, stale plugin cache (0.48.x mismatch), duplicate subagents, WiFi/connectivity stalls, stub/skipped rows, outcome FAIL with evidence PASS
- **3 idle polls on same row → investigate** (do not silently poll)
- Track token counts as data (do not block on marketing "10× cost" claim)

## D. Fix loop (SB codebase)

On any friction:

1. Diagnose from logs (no guessing).
2. Fix in SB repo (prefer `enterprise-e2e/round6`; cherry-pick verified fixes to `main` per `docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md`).
3. Commit; log in cherry-pick doc when verified.
4. `graphify update .` after substantive SB edits; `graphify query` before scoped work.
5. Re-run affected row with `SB_E2E_MATRIX_FORCE=1`.
6. Persist **new** SB issues to `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` (baseline **76** unique IDs — 0 new for strict-clean).

## E. Policies (non-negotiable)

- **Single driver:** poll-only while batch alive and log growing; no duplicate monitors/drivers.
- **Do not kill** healthy driver **<45 min** unless confirmed stuck/dead.
- `SB_E2E_MONITOR_AUTO_RESTART=0`
- `RTK_DISABLED=1` for harness/preflight verbatim output
- **No** `claude auth login/logout` — custom API gateway / token access
- On **429**: retry every **1 minute** (not auth failure)
- Fresh end-user install path when plugin cache cross-contaminates (`install-claude.sh` from current tip)
- Non-TTY agent shell: **tmux** or `sb_run_detached_pty` for matrix driver
- Recommended tools **opted-in and verified enforced:** Graphify, agentmemory, RTK, Context Mode, Alumnium
- Compaction on context full — **not** `/clear`
- No `gsd` references anywhere

## F. Outcome assessment (per row + session)

Score all criteria in `OUTCOME-ASSESSMENT-RUBRIC.md` / `outcome-criteria-registry.json`, including:

- Contextual dynamic workflow tailoring
- Verification & validation loops
- Quality gates engagement
- Spec-to-release traceability
- Intent-aligned results
- Knowledge management (Graphify + agentmemory JIT retrieval)
- **WBS decomposition, supervision, verification, validation** (meta-supervision loop)
- **Autonomous delivery:** SB drives to completion from vague prompt; `/silver:clarify` when needed — assist-only = FAIL

Any mandatory outcome failure = **row FAIL** = round **not** strict-clean.

## G. Every poll report (minimum table)

| Driver PID alive? | Active row/skill | Last meaningful TUI lines | Evidence PASS count | Outcome PASS count | Friction this cycle | Action taken |
|-------------------|------------------|---------------------------|---------------------|--------------------|---------------------|--------------|

## H. Resume first actions

1. Read handoff + ledger; `kill -0 <driver_pid>`
2. If dead: clear stale `.e2e-live-test.lock`; single `--resume` relaunch (tmux if needed)
3. If alive: poll + friction watch only — **no second driver**
4. Post first checkpoint within **90s**
5. Continue until Round 6 strict-clean + Phase C, then evaluate release pair with Round 5

## One-liner (fresh session)

> Use ROUND-6-SESSION-HANDOFF.md + this addendum: SB repo root, one `composer-2.5` background operator resumed across turns, report every 60–90s poll with active TUI friction watch, fix SB immediately and cherry-pick to main, strict-clean = ladder + matrix + all outcome criteria + 0 new issues vs 76, never pause for me, no claude login, 429 retry 1min, single driver only.
