# Enterprise E2E Host Certification Methodology

> **Share this path with sibling agents (Cursor, Claude, Codex):**  
> `docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md`  
> Canonical on **`main`** — host tracks cherry-pick or link; do not fork per-host copies.

**Status:** Active — 2026-07-01  
**Audience:** Codex, Cursor, and Claude operator sessions certifying Silver Bullet on `enterprise-grade-test-app`  
**Authority:** Supersedes ad-hoc “run 22 rows first” loops; complements [ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md](./ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md)

**Related docs:**

| Doc | Path |
|-----|------|
| Shared harness | [`.planning/enterprise-e2e/SHARED-HARNESS.md`](../../.planning/enterprise-e2e/SHARED-HARNESS.md) |
| Host env matrix | [`.planning/enterprise-e2e/HOST-CONFIG.md`](../../.planning/enterprise-e2e/HOST-CONFIG.md) |
| Outcome rubric | [`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) |
| Live test runbook | [`docs/ENTERPRISE-E2E-LIVE-TEST.md`](../ENTERPRISE-E2E-LIVE-TEST.md) |
| Operator prompt | [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) |
| Fixture branch policy | [`.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md`](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md) |
| Cherry-pick policy | [`docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) |

---

## 1. Effectiveness verdict

**Full 22-row live matrix as the primary debug loop is low throughput.** Rounds 1–3 and Codex-1 demonstrated that jumping straight to Tier C wastes quota, produces ledger/monitor drift, and blocks harness fixes behind long TUI stalls.

| Approach | Verdict |
|----------|---------|
| **Staged gates (Tier A → B → C)** | **Recommended** — fast structural signal before LLM spend |
| **Full 22-row matrix as first loop** | **Deprecated** for bring-up and mid-round debug |
| **Structural / offline suite** | **Highly effective** — catches script/doc/registry drift without TUI |
| **Monitor “22/22 COMPLETE” without ledger reconcile** | **Anti-pattern** — observed Round 3 drift |
| **2 consecutive strict-clean rounds** | **Still required** for host release sign-off (unchanged) |

**Honest scope:** This program certifies SB harness + workflow routing on a fixture app with operator supervision. It does **not** prove homepage marketing stats, cold-install SLOs, or statistical reliability across providers without additional claims mapping (see registries below).

---

## 2. What worked / failed (Round Codex-1)

| Worked | Failed / friction |
|--------|---------------------|
| Phase A ladder **8/8** with 2× verify per rung | Full-matrix-first debug loop — rows 2–5 stalled on quota + stop-hook |
| Harness fixes on `enterprise-e2e/codex` (scorer, hook trust, quiet timeout) | Scorer false negatives (row 2) — required post-invoke rescore |
| Host-isolated locks/logs (`.e2e-live-test-codex.lock`, codex row logs) | 429 quota — needs scheduled retry, not auth churn |
| Tier A structural suite green before live | Agent-shell TUI watchers — fragile vs durable daemon driver |
| Rows 1, 6, 7 strict-clean when batch healthy | Parallel host branch stomp without fixture isolation |

**Takeaway:** Codex-1 proved harness value but did not complete strict-clean. Resume on **staged gates**, not “force full matrix until green.”

---

## 3. Tier A / B / C gate model

Gates are **sequential**. Do not start Tier B until Tier A is green. Do not start Tier C until Tier B smoke passes.

### Summary table

| Tier | Layer | TUI? | Purpose |
|------|-------|------|---------|
| **A** | Offline / pre-release structural | **No** | Wiring, registries, surface isolation, outcome harness |
| **B** | Live smoke (rows **1, 3, 6**) | **Yes** | Router + feature + fast paths before full burn |
| **C** | Full matrix **22/22** + Phase C strict-clean | **Yes** | Release pair gate (2 consecutive strict-clean rounds) |

### Tier A — offline / pre-release (no TUI)

Run **all** green before `SB_ENTERPRISE_E2E_LIVE=1`.

| Check | Command / artifact |
|-------|-------------------|
| Structural harness | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Validation overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run` |
| Pre-release overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` |
| Validation overlay structural test | `bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh` |
| Host install surface **D16** | `bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host <host>` |
| Surface structural test | `bash tests/scripts/test-validate-host-install-surface.sh` |
| Tri-host install smoke (per host) | `RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host <host>` |
| Hook delivery preflight | `SB_E2E_LIVE_RUNTIME=<host> bash tests/e2e-live/hook-delivery-preflight.sh` |
| Review-fix-ladder smoke | `SILVER_BULLET_RUNTIME=<host> bash tests/live/test-live-review-fix-ladder-smoke.sh` |
| Host preflight | `bash scripts/run-enterprise-e2e-live-test.sh --host <host> --preflight-only` |
| Dry-run matrix | `SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=<host> bash scripts/run-enterprise-e2e-matrix.sh` |
| Test-app branch structural | `RTK_DISABLED=1 bash tests/scripts/test-enterprise-e2e-test-app-branch.sh` |
| Claims registries | `docs/testing/validation-claims-registry.json`, `docs/testing/pre-release-claims-registry.json` |

**Registries:** validation overlay = 6 outcome/telemetry gate claims; pre-release overlay = feature/install claims (tri-host, catalog, hooks). See [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) §Validation vs pre-release.

### Tier B — live smoke (rows 1, 3, 6)

| Row | WF slug | Why smoke |
|-----|---------|-----------|
| 1 | `silver-router` | Routing-only — cheapest live signal |
| 3 | `silver-feature` | Parent for rows 21–22 — catches orchestrator + implement path |
| 6 | `silver-fast` | Fast path + hook trust — high signal / lower cost |

```bash
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_LIVE_RUNTIME=<host>
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-<HOST>-1-LEDGER.md
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 1 3 6
```

**After each row:** post-invoke rescore (§6). **Gate:** all three rows evidence PASS + outcome PASS before Tier C.

### Tier C — full matrix + strict-clean

1. **review-fix-ladder** 8/8 × 2 verify (if not already complete in round)
2. Live matrix rows **1–22** (`SB_ENTERPRISE_E2E_LIVE=1`)
3. **Phase C** (all green):
   - `bash tests/scripts/test-outcome-assessment.sh`
   - `bash tests/run-all-tests.sh`
   - `bash scripts/run-enterprise-e2e-validation-overlay.sh --live`
   - `bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` (+ `--live` before release)
   - `bash scripts/lib/enterprise-e2e-ledger-reconcile.sh <matrix-log>`
   - `SB_E2E_RCS_TRIHOST=full bash scripts/enterprise-e2e-rcs.sh` (RCS ≥ 85)

**Strict-clean** = ladder 8/8 + matrix 22/22 + every row `enterprise_e2e_outcome_row_passes` + blocking autonomy gates + Phase C green + **0 new issues** vs baseline (`docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`).

**Release:** 2 consecutive strict-clean rounds per host ([`ROUND-N-GATES.md`](../../.planning/enterprise-e2e/ROUND-N-GATES.md)).

---

## 4. Fixture branch rules

Pattern: **`enterprise-e2e/round-<N>-<host>`** @ baseline SHA (test app, not SB `main`).

| Host | SB harness branch | Test-app fixture branch | Baseline SHA |
|------|-------------------|-------------------------|--------------|
| Claude | `enterprise-e2e/round6` | `enterprise-e2e/round-8-claude` | `8482e60` |
| Codex | `enterprise-e2e/codex` | `enterprise-e2e/round-8-codex` | `8482e60` |
| Cursor | `enterprise-e2e/cursor` | `enterprise-e2e/round-1-cursor` (worktree) | `8482e60` |

**Rules:**

1. **Day-0:** create fixture branch from baseline SHA; never target test-app `main` for live rows.
2. **No stomp:** never `checkout -B` another host's fixture branch on a shared clone.
3. **Dirty + correct branch:** OK (matrix in progress). **Dirty + wrong branch:** fail-fast — use worktree ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
4. Env overrides: `SB_E2E_TEST_APP_BRANCH`, `SB_E2E_TEST_APP_BASELINE_SHA`, `SB_E2E_TEST_APP_ROUND`.

---

## 5. Cherry-pick policy (no main switch for deploy)

- **Harness fixes** commit on host branch (`enterprise-e2e/codex`, `enterprise-e2e/cursor`, `enterprise-e2e/round6`).
- **Verified fixes** cherry-pick to `main` per [`ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) — paths only when mixed with ledger noise.
- **Do not** switch live matrix driver to `main` mid-round for deploy; re-run host install (`install-codex.sh`, etc.) from pinned SB SHA on host branch.
- **Docs on `main`** (this file) are the cross-agent share surface; host prompts link here.

---

## 6. Scorer / rescore policy

| Event | Action |
|-------|--------|
| **Default after every row invoke** | Post-invoke rescore: `enterprise_e2e_outcome_row_passes` on row attempt log |
| **After harness fix** | `SB_E2E_MATRIX_FORCE=1` on affected row(s), then rescore |
| **Evidence PASS + outcome FAIL** | Treat as scorer/harness bug until rescore passes or issue filed |
| **Ledger vs monitor mismatch** | Ledger wins; run `enterprise-e2e-ledger-reconcile.sh` |

Read [OUTCOME-ASSESSMENT-RUBRIC.md](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) before scoring. All **27 criteria** + blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`).

---

## 7. Quota-aware scheduling

- **429 / Token Plan:** retry same row every **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`) — not auth failure.
- **Do not** rotate API keys or restart auth mid-row without evidence of auth failure.
- **Tier B before Tier C** conserves quota during bring-up.
- **Surface gate before matrix:** Tier A `validate-host-install-surface.sh` + tri-host smoke must pass before spending live rows.
- **Narrow strict-clean during host bring-up:** Tier B smoke only until harness stable; defer full strict-clean claim until Tier C.

---

## 8. Single driver / daemon

| Policy | Value |
|--------|-------|
| Drivers per host | **1** — no parallel matrix operators |
| `SB_E2E_MONITOR_AUTO_RESTART` | **0** |
| Healthy driver | Do not kill **< 45 min** unless confirmed stuck/dead |
| Watchers | Prefer **durable daemon** (`run-enterprise-e2e-matrix.sh` / tmux batch) — not agent-shell poll loops as primary driver |
| Parent orchestrator | One `composer-2.5` background worker; resume same worker ID |
| Poll cadence | 60–90s substantive checkpoints |

Host-isolated artifacts: see [HOST-CONFIG.md](../../.planning/enterprise-e2e/HOST-CONFIG.md).

---

## 9. Cross-agent isolation

When Claude Round 6, Codex, and Cursor run in parallel:

1. **Separate SB git branches** per host — never commit Codex harness to `enterprise-e2e/cursor` or Claude `round6`.
2. **Separate fixture branches** per host — see §4.
3. **Separate locks** — `.e2e-live-test.lock` (Claude), `.e2e-live-test-codex.lock`, `.e2e-live-test-cursor.lock`.
4. **Never** `pkill` another host's monitor/driver PIDs.
5. **Never** remove another host's lock unless that host's driver PID is confirmed dead.
6. **Cursor worktree** when shared clone is dirty on another branch ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
7. **Single workspace per host** for SB fixes — test app is matrix CWD only.

---

## 10. Host execution prompts (per-track)

| Host | Prompt |
|------|--------|
| Codex | [`.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Cursor | [`.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Claude R6 | [`.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md`](../../.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md) |

All tracks **must read this methodology doc** at session start.

---

## Appendix A — Codex-1 status (do not re-duplicate harness work)

**Round:** Codex-1 on `enterprise-e2e/codex`  
**Ledger:** [`.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md)

| Item | Status |
|------|--------|
| Ladder 8/8 | **Complete** |
| Matrix | **3/22** strict-clean (rows 1, 6, 7); rows 2–5 in flight / FAIL at last checkpoint |
| Harness fixes landed | `959de0ea` quiet timeout + scorer; `b4f471b3` TUI-aware outcome; `d24207e3` hook trust; `ac4b9322` OUT-SKILL-01 |
| **Retry force4** ([`6519e3ae`](../../.planning/enterprise-e2e/)) | Checkpoint in flight on codex branch — **do not re-implement** unless commits are dead/reverted. Resume via Tier A→B→C per this doc. |
| Next Codex action | Tier A green → Tier B rows 1,3,6 on `enterprise-e2e/round-8-codex@8482e60` → post-invoke rescore → Tier C |

---

## Appendix B — Quick Tier A copy-paste

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_LIVE_RUNTIME=codex   # or cursor | claude
cd "$SB_ROOT"
export RTK_DISABLED=1

bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
bash tests/scripts/test-outcome-assessment.sh
bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host "$SB_E2E_LIVE_RUNTIME"
bash scripts/run-tri-host-install-smoke.sh --host "$SB_E2E_LIVE_RUNTIME"
SB_E2E_LIVE_RUNTIME="$SB_E2E_LIVE_RUNTIME" bash tests/e2e-live/hook-delivery-preflight.sh
bash scripts/run-enterprise-e2e-live-test.sh --host "$SB_E2E_LIVE_RUNTIME" --preflight-only
SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh
```
