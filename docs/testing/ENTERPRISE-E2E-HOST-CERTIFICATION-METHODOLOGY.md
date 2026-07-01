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
| Test-app branch policy | [`.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md`](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md) |
| Outcome rubric | [`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) |
| Cursor execution prompt | [`.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Live test runbook | [`docs/ENTERPRISE-E2E-LIVE-TEST.md`](../ENTERPRISE-E2E-LIVE-TEST.md) |
| Operator prompt | [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) |
| Fixture / worktree addendum | [`.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md`](../../.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md) |
| Cherry-pick policy | [`docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) |

---

## 1. Effectiveness verdict

**Full 22-row live matrix as the primary debug loop is low throughput.** Rounds 1–3, Codex-1, and Cursor-1 demonstrated that jumping straight to Tier C / T3 wastes quota, produces ledger/monitor drift, and blocks harness fixes behind long TUI stalls.

| Approach | Verdict |
|----------|---------|
| **Staged gates (T0 → T1 → T2 → T3)** | **Recommended** — fast structural signal before LLM spend |
| **Full 22-row matrix as first loop** | **Deprecated** for bring-up and mid-round debug |
| **Structural / offline suite** | **Highly effective** — catches script/doc/registry drift without TUI |
| **Monitor “22/22 COMPLETE” without ledger reconcile** | **Anti-pattern** — observed Round 3 + Cursor-1 drift |
| **2 consecutive strict-clean rounds** | **Still required** for host release sign-off (unchanged) |

**Honest scope:** This program certifies SB harness + workflow routing on a fixture app with operator supervision. It does **not** prove homepage marketing stats, cold-install SLOs, or statistical reliability across providers without additional claims mapping (see registries below).

---

## 2. What worked / failed (by host track)

### Round Codex-1

| Worked | Failed / friction |
|--------|---------------------|
| Phase A ladder **8/8** with 2× verify per rung | Full-matrix-first debug loop — rows 2–5 stalled on quota + stop-hook |
| Harness fixes on `enterprise-e2e/codex` (scorer, hook trust, quiet timeout) | Scorer false negatives (row 2) — required post-invoke rescore |
| Host-isolated locks/logs (`.e2e-live-test-codex.lock`, codex row logs) | 429 quota — needs scheduled retry, not auth churn |
| Tier A structural suite green before live | Agent-shell TUI watchers — fragile vs durable daemon driver |
| Rows 1, 6, 7 strict-clean when batch healthy | Parallel host branch stomp without fixture isolation |

**Takeaway:** Codex-1 proved harness value but did not complete strict-clean. Resume on **staged gates**, not “force full matrix until green.”

### Round Cursor-1

| Worked | Failed / friction |
|--------|---------------------|
| Tiered T0→T1 before burning full matrix | Full 22-row batch as first debug loop — 10/22 then long retry cycles |
| Host branch `enterprise-e2e/cursor` + worktree `enterprise-grade-test-app-cursor` | Shared clone dirty-branch collisions before worktree policy |
| tmux drivers (`cursor-e2e-retry*`) vs nohup | nohup batches: 0B logs for ~30 min (stdout buffering) — monitor blind |
| Targeted `SB_E2E_MATRIX_FORCE=1` on failing row subsets | Full 22-row reruns after each harness fix — wasted quota |
| `enterprise_e2e_assert_host_git_branch` fail-fast | retry3g ran on wrong test-app branch (`round-8-codex`) — branch guard needed |
| Single Composer 2.5 TUI monitor subagent | Parent resume churn when monitor respawned each turn |
| `SB_E2E_SKIP_CURSOR_INSTALL=1` during batch retries | Re-install mid-batch invalidated surface assumptions |

**Takeaway:** Cursor-1 reached **18/22** live ledger pass with retry3f; rows 12, 15, 16, 18 remain. Resume per **T0→T3** — do not restart full 22 if tiered path supersedes an in-flight subset retry.

---

## 3. Tiered certification (T0 → T3)

Gates are **sequential**. Do not start T*n+1* until T*n* is green. **No T3** until **T1 passes twice** on the host worktree with `SB_E2E_SURFACE_SKIP=0`.

> **Legacy alias:** T0 ≈ Tier A; T3 ≈ Tier C. Old “Tier B (rows 1, 3, 6)” is superseded by T1 + T2 below.

### Summary table

| Tier | Layer | TUI? | Purpose |
|------|-------|------|---------|
| **T0** | Structural + surface + branch assert | **No** | Wiring, registries, host install surface, branch guards — no LLM |
| **T1** | Live smoke — row **1** (`silver-router`) × **2** | **Yes** | Cheapest live signal; proves install + invoke + outcome path |
| **T2** | Live **5-row SDLC slice** | **Yes** | Router → feature → fast → test → ship paths before full burn |
| **T3** | Full matrix **22/22** + Phase C strict-clean | **Yes** | Release pair gate (2 consecutive strict-clean rounds) |

**T2 SDLC slice (recommended rows):** `1 3 6 7 14` — router, feature parent, fast path, test, release. Adjust only with documented rationale in the round ledger.

### T0 — structural + surface + branch assert (no TUI)

Run **all** green before `SB_ENTERPRISE_E2E_LIVE=1`.

| Check | Command / artifact |
|-------|-------------------|
| SB harness branch assert | `enterprise_e2e_assert_host_git_branch` (via live-test / matrix preflight) |
| Test-app branch assert | Worktree @ `enterprise-e2e/round-{N}-{host}` — see [TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md) |
| Structural harness | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Host install surface **D16** | `bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host <host>` |
| Validation overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run` |
| Pre-release overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` |
| Validation overlay structural test | `bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh` |
| Surface structural test | `bash tests/scripts/test-validate-host-install-surface.sh` |
| Tri-host install smoke (per host) | `RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host <host>` |
| Hook delivery preflight | `SB_E2E_LIVE_RUNTIME=<host> bash tests/e2e-live/hook-delivery-preflight.sh` |
| Review-fix-ladder smoke | `SILVER_BULLET_RUNTIME=<host> bash tests/live/test-live-review-fix-ladder-smoke.sh` |
| Host preflight | `bash scripts/run-enterprise-e2e-live-test.sh --host <host> --preflight-only` |
| Dry-run matrix | `SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=<host> bash scripts/run-enterprise-e2e-matrix.sh` |
| Test-app branch structural | `RTK_DISABLED=1 bash tests/scripts/test-enterprise-e2e-test-app-branch.sh` |
| Claims registries | `docs/testing/validation-claims-registry.json`, `docs/testing/pre-release-claims-registry.json` |

**Registries:** validation overlay = 6 outcome/telemetry gate claims; pre-release overlay = feature/install claims (tri-host, catalog, hooks). See [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) §Validation vs pre-release.

### T1 — live smoke (row 1 × 2)

**Gate:** row 1 (`silver-router`) must pass **twice consecutively** with:

- `SB_E2E_SURFACE_SKIP=0`
- Fresh `install-<host>.sh` before **first** T1 attempt (and after any `main` cherry-pick deploy — see §5)
- Full row attempt log (non-trivial byte size) + live `enterprise_e2e_outcome_row_passes`

```bash
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_LIVE_RUNTIME=<host>
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-<HOST>-1-LEDGER.md
RTK_DISABLED=1 bash scripts/install-<host>.sh
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 1   # run 1
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 1   # run 2
```

**After each row:** post-invoke outcome check (§6). **Do not** count `retry2-rescore.sh` output toward T1 pass.

### T2 — live 5-row SDLC slice

```bash
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_LIVE_RUNTIME=<host>
export SB_E2E_SURFACE_SKIP=0
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 1 3 6 7 14
```

**Gate:** all five rows evidence PASS + outcome PASS before T3.

### T3 — full matrix + strict-clean

1. **review-fix-ladder** 8/8 × 2 verify (if not already complete in round)
2. Live matrix rows **1–22** (`SB_ENTERPRISE_E2E_LIVE=1`, `SB_E2E_SURFACE_SKIP=0`)
3. **Phase C** (all green) — see §7

**Strict-clean** = ladder 8/8 + matrix 22/22 + every row live `enterprise_e2e_outcome_row_passes` + blocking autonomy gates + Phase C green + **0 new issues** vs baseline (`docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`). See §6 for what does **not** count.

**Release:** 2 consecutive strict-clean rounds per host ([`ROUND-N-GATES.md`](../../.planning/enterprise-e2e/ROUND-N-GATES.md)).

---

## 4. Hard isolation (parallel hosts)

When Claude Round 6, Codex, and Cursor run in parallel:

| Resource | Rule |
|----------|------|
| **SB harness branch** | One per host — e.g. `enterprise-e2e/cursor`, `enterprise-e2e/codex`, `enterprise-e2e/round6`. Never commit Codex harness to Cursor branch. |
| **Test-app fixture** | Dedicated branch `enterprise-e2e/round-{N}-{host}`; Cursor uses worktree `~/projects/enterprise-grade-test-app-cursor` |
| **Lock file** | Host-suffixed only — `.e2e-live-test-cursor.lock`, `.e2e-live-test-codex.lock`, `.e2e-live-test.lock` (Claude). Lock **only your host**. |
| **Matrix log** | `.e2e-matrix-cursor-live.log`, `.e2e-matrix-codex-live.log`, etc. |
| **Row attempt log** | `.e2e-row{N}-cursor-attempt.log` (host suffix mandatory for Cursor/Codex) |
| **Driver PIDs** | Never `pkill` another host's monitor/driver children |
| **Workspace** | Single SB workspace per host for harness fixes; test app is matrix CWD only |

**Branch guard:** `enterprise_e2e_assert_host_git_branch` must abort if the SB repo is on the wrong harness branch — observed retry3g on wrong fixture branch when guard was bypassed.

Full matrix: [HOST-CONFIG.md](../../.planning/enterprise-e2e/HOST-CONFIG.md), [TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md).

### Fixture branch rules

**Canonical pattern:** `enterprise-e2e/round-<n>-<host>` @ baseline SHA (test app, not SB `main`).

| Host | SB harness branch | Test-app fixture branch | Baseline SHA |
|------|-------------------|-------------------------|--------------|
| Claude | `enterprise-e2e/round6` | `enterprise-e2e/round-8-claude` | `8482e60` |
| Codex | `enterprise-e2e/codex` | `enterprise-e2e/round-8-codex` | `8482e60` |
| Cursor | `enterprise-e2e/cursor` | `enterprise-e2e/round-1-cursor` (worktree) | `8482e60` |

**Rules:**

1. **Day-0:** create fixture branch from baseline SHA; never target test-app `main` for live rows.
2. **No stomp:** never `checkout -B` another host's fixture branch on a shared clone.
3. **Dirty + correct branch:** OK (matrix in progress). **Dirty + wrong branch:** fail-fast — use worktree ([OPERATIONAL-ADDENDUM.md](../../.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md) §worktree policy).
4. Env overrides: `SB_E2E_TEST_APP_BRANCH`, `SB_E2E_TEST_APP_BASELINE_SHA`, `SB_E2E_TEST_APP_ROUND`.

---

## 5. Cherry-pick deploy gate (no main switch for live batches)

- **Harness fixes** commit on host branch (`enterprise-e2e/codex`, `enterprise-e2e/cursor`, `enterprise-e2e/round6`).
- **Verified fixes** cherry-pick to `main` per [`ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) — paths only when mixed with ledger noise.
- **Do not** switch live matrix driver to `main` mid-round for deploy.

**Before live batches after `main` moves:**

1. Cherry-pick surface/install commits onto the host E2E branch
2. `bash scripts/install-<host>.sh`
3. `bash scripts/validate-host-install-surface.sh --host <host>`
4. Confirm `SB_E2E_SURFACE_SKIP=0` for T1+ runs

- **Docs on `main`** (this file) are the cross-agent share surface; host prompts link here.

---

## 6. Scorer, rescore, and failure classification

### Harness vs agent vs fixture

Record `failure_class` on every Fail row in the ledger matrix table:

| Class | Meaning | Fix path |
|-------|---------|----------|
| **`harness`** | Script, timeout, scorer, TUI adapter, branch guard, install surface | Targeted harness commit on host branch; `SB_E2E_MATRIX_FORCE=1` on affected rows |
| **`agent`** | Agent violated rubric but harness is correct | Do **not** relax rubric unless rubric is wrong — file issue or improve prompt/skill routing |
| **`fixture`** | Test-app fixture state, wrong branch, stale parent evidence for internal rows 21–22 | Reset fixture branch / re-seed parent rows |

> **Mapping:** legacy `product` → `agent`; `environmental` (429, ENOTFOUND) → retry with backoff, not harness relax.

| Event | Action |
|-------|--------|
| **Default after every row invoke** | Live `enterprise_e2e_outcome_row_passes` on row attempt log |
| **After harness fix** | `SB_E2E_MATRIX_FORCE=1` on affected row(s) only — not full 22-row rerun |
| **Evidence PASS + outcome FAIL** | Classify: harness bug vs agent gap vs fixture — see table above |
| **Ledger vs monitor mismatch** | Ledger wins; run `enterprise-e2e-ledger-reconcile.sh` |

### Strict-clean = live only

| Counts toward strict-clean | Dev feedback only (never strict-clean) |
|----------------------------|----------------------------------------|
| Live matrix invoke with non-trivial attempt log | `retry2-rescore.sh` / post-hoc rescoring without live re-invoke |
| Live `enterprise_e2e_outcome_row_passes` on attempt log | Evidence-only PASS from stale tmux tail |
| Phase C green after live matrix | Ledger rows marked Pass without live log ref |

Read [OUTCOME-ASSESSMENT-RUBRIC.md](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) before scoring. All **27 criteria** + blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`).

### Targeted retries

Prefer **`SB_E2E_MATRIX_FORCE=1` on failing row subsets** after harness fixes — not full 22-row reruns. Example: retry3g targets rows `12 15 16 18` only.

```bash
export SB_E2E_MATRIX_FORCE=1 SB_E2E_SKIP_CURSOR_INSTALL=1  # cursor batch retries
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 12 15 16 18
```

---

## 7. Phase C early (before long live batches)

Run Phase C structural checks **before** spending quota on T2/T3:

| Check | Command |
|-------|---------|
| Full test suite | `bash tests/run-all-tests.sh` |
| Ledger reconcile | `bash scripts/lib/enterprise-e2e-ledger-reconcile.sh <matrix-log>` |
| Outcome harness | `bash tests/scripts/test-outcome-assessment.sh` |

**Schedule:** nightly on the host E2E branch while matrix batches run. Catches harness drift without waiting for 22-row completion.

**T3 Phase C (live, all green):**

- `bash tests/scripts/test-outcome-assessment.sh`
- `bash tests/run-all-tests.sh`
- `bash scripts/run-enterprise-e2e-validation-overlay.sh --live`
- `bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` (+ `--live` before release)
- `bash scripts/lib/enterprise-e2e-ledger-reconcile.sh <matrix-log>`
- `SB_E2E_RCS_TRIHOST=full bash scripts/enterprise-e2e-rcs.sh` (RCS ≥ 85)

---

## 8. Quota-aware scheduling

- **429 / Token Plan:** retry same row every **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`) — not auth failure.
- **ENOTFOUND / transient DNS:** backoff **60–120s** before retry; do not classify as harness failure on first occurrence.
- **Do not** rotate API keys or restart auth mid-row without evidence of auth failure.
- **T1/T2 before T3** conserves quota during bring-up.
- **Surface gate before matrix:** T0 `validate-host-install-surface.sh` + tri-host smoke must pass before spending live rows.

---

## 9. Single driver / monitor

| Policy | Value |
|--------|-------|
| Drivers per host | **1** — no parallel matrix operators |
| `SB_E2E_MONITOR_AUTO_RESTART` | **0** |
| Healthy driver | Do not kill **< 45 min** unless confirmed stuck/dead |
| Drivers | **tmux** sessions — not `nohup` (stdout buffering → 0B logs ~30 min, monitor blind) |
| Monitor agent | **One** Composer 2.5 TUI monitor subagent per host; poll + friction jsonl; **minimize parent resume churn** — resume same worker ID |
| Poll cadence | 60–90s substantive checkpoints |
| Batch env | `SB_E2E_SKIP_CURSOR_INSTALL=1` during retry batches (Cursor); fresh install only at T1 gate or post cherry-pick |

Host-isolated artifacts: [HOST-CONFIG.md](../../.planning/enterprise-e2e/HOST-CONFIG.md), [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](../../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md).

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
| **Retry force4** | Checkpoint in flight on codex branch — **do not re-implement** unless commits are dead/reverted. Resume via T0→T3 per this doc. |
| Next Codex action | T0 green → T1 row 1 ×2 → T2 slice → T3 |

---

## Appendix B — Cursor-1 status

**Round:** Cursor-1 on `enterprise-e2e/cursor`  
**Ledger:** [`.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md)  
**Harness HEAD:** `94ff696d` + cherry-picks through `392eea37`

| Item | Status |
|------|--------|
| Ladder 8/8 | **Complete** |
| Matrix (live ledger) | **18/22** — rows 12, 15, 16, 18 Fail (`failure_class: outcome`) |
| retry3g | In flight on rows 12, 15, 16, 18 — verify branch + log refs before counting |
| Next Cursor action | T0 green → T1 row 1 ×2 (`SB_E2E_SURFACE_SKIP=0`) → targeted FORCE on 12/15/16/18 or T2 slice |

---

## Appendix C — Quick T0 copy-paste

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_LIVE_RUNTIME=cursor   # or codex | claude
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app-cursor  # cursor only
cd "$SB_ROOT"
export RTK_DISABLED=1

bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
bash tests/scripts/test-outcome-assessment.sh
bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host "$SB_E2E_LIVE_RUNTIME"
bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
bash scripts/run-tri-host-install-smoke.sh --host "$SB_E2E_LIVE_RUNTIME"
SB_E2E_LIVE_RUNTIME="$SB_E2E_LIVE_RUNTIME" bash tests/e2e-live/hook-delivery-preflight.sh
bash scripts/run-enterprise-e2e-live-test.sh --host "$SB_E2E_LIVE_RUNTIME" --preflight-only
SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh
```
