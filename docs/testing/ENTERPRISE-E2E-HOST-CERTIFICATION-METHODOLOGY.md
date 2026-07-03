# Enterprise E2E Host Certification Methodology

> **Share this path with sibling agents (Cursor, Claude, Codex):**  
> `docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md`  
> Canonical on **`main`** — host tracks cherry-pick or link; do not fork per-host copies.

**Status:** Active — 2026-07-02  
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
| **Repeat matrix/ladder/T1 rows at same install** | **Deprecated** — one clean pass per row/criterion @ install version (see §11) |
| **Rescore / evidence-only PASS without live rerun** | **Disqualifying** for certification credit (see §5a, §6) |
| **Inherited baseline / pre-existing fixture artifacts** | **Disqualifying** without live agent authorship (see §5a) |
| **ROW_ALREADY_PASSED_SAME_INSTALL on first host certification** | **Disqualifying** — install-skip only after first strict-clean pair @ install version (see §5a, §6a) |

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

### Phase ordering (mandatory)

Execute in this order — do not skip ahead or claim certification credit from later phases without completing earlier ones:

| Phase | Alias | What runs |
|-------|-------|-----------|
| **T0** | Tier A structural | Offline harness, outcome tests, surface validation, dry-run matrix (§3 Tier A) |
| **T1** | Tier B row 1 | Single live `silver-router` FORCE @ install version — routing smoke with outcome PASS |
| **T2** | Tier B smoke | Live rows **1, 3, 6** (router + feature parent + fast path) |
| **Phase A** | review-fix-ladder | 8/8 rungs — one live pass per rung @ install version |
| **Full matrix** | Tier C | Live rows **1–22** — one pass per row @ install version |
| **Phase C** | Release gates | Outcome harness, run-all-tests, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 |

**Rescore ≠ strict-clean.** Post-invoke rescoring may flip harness evidence for debugging; only **live strict-clean invocations** count toward host certification and consecutive-round pairs.

**Ship-readiness consistency:** Row 16 (`ship-readiness`) outcome must match fixture state — `NOT_MERGE_READY` (or equivalent) **cannot** be scored PASS. Audit-only triad docs (row 15) without product delta is **not** certified delivery.

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

1. **review-fix-ladder** 8/8 — **one live pass per rung** when already green at current install version (§11); legacy 2× verify only when install version changes or `SB_E2E_MATRIX_FORCE=1`
2. Live matrix rows **1–22** (`SB_ENTERPRISE_E2E_LIVE=1`) — **one pass per row** when ledger/registry shows Pass @ current `SB_INSTALL_VERSION_KEY`
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

## 5a. Anti-faking and disqualifying evidence

Operators **must not** declare a row PASS for host certification unless the row satisfies **§5b required evidence gates**. The following categories are **forbidden** or **disqualifying** — if observed, mark the row **FAIL** (or void the round) and re-run live strict-clean:

| # | Category | Description | Operator action |
|---|----------|-------------|-----------------|
| 1 | **Pre-existing evidence** | Row passes on inherited baseline commits (e.g. `826cb5c`, `8482e60`) or fixture files present before the live agent session without live agent authoring that deliverable | Reset fixture branch to baseline SHA; re-run row with `SB_E2E_MATRIX_FORCE=1`; require committed delta or documented brownfield waiver |
| 2 | **Harness rescoring** | E2E-089-style log rescoring flipping FAIL→PASS without a live strict-clean rerun (evidence-only rescoring after timeout/empty logs) | Rescore is diagnostic only — **does not** grant certification credit; live rerun required |
| 3 | **Timeout / empty logs** | FORCE passes with **0–148 B** logs (timeout-only, connection noise, no captured workflow output) | FAIL row; fix harness (E2E-086 headless log streaming) or extend timeout; re-run live |
| 4 | **Audit-only sessions** | Agent ran but **zero product delta**: routing-only row 1 with no routing artifact; verify-only row 7; triad docs-only row 15; ship-readiness `NOT_MERGE_READY` still PASS | FAIL row — dirty tree with no commits = not certified product delivery |
| 5 | **Install-skip on first certification** | `ROW_ALREADY_PASSED_SAME_INSTALL` or `evidence_present` reusing prior-round evidence when certifying host for the **first** time at an install fingerprint | Install-skip allowed **only after** the first strict-clean pair @ install version (§6a); first certification requires live invocations |
| 6 | **Internal gates without parent live work** | Rows 21–22 passing on parent markers when parent rows 3/4 were not live strict-clean at current install fingerprint | Re-run parent rows 3/4 live; internal rows inherit parent evidence only from live strict-clean parents |

**Cross-host contamination** (E2E-090): matrix rows executed on another host's fixture branch (e.g. Claude rows on `round-8-codex`) **disqualify the round** — reset fixture, verify `enterprise_e2e_assert_host_git_branch`, use per-host worktree.

**Brownfield waiver (narrow):** Pre-existing artifact may count only when operator documents **file:line** evidence that the artifact existed before the row prompt and the row's contract explicitly allows verification-without-mutation. Default: **no waiver** — live authorship required.

---

## 5b. Required evidence gates (per row)

Every row claimed **PASS** for certification must satisfy **all** gates:

| Gate | Requirement |
|------|-------------|
| **Log size floor** | Row attempt log **> 2048 bytes** substantive workflow output, **or** explicit brownfield waiver in ledger with file:line pre-existence proof |
| **Live strict-clean only** | Row invoked via live matrix driver (`SB_ENTERPRISE_E2E_LIVE=1`) at current install fingerprint — not rescore-only, not dry-run, not monitor replay |
| **Product delta** | **Committed delta** on fixture branch (`git log` shows row-session commit) **or** documented brownfield waiver — uncommitted dirty tree alone is insufficient |
| **Host-agent authorship** | Outcome checklist attests **host-agent** (`cursor-agent`, Codex TUI, Claude TUI) authored the deliverable — operator parent routing-only does not satisfy implement rows |
| **Outcome PASS** | `enterprise_e2e_outcome_row_passes` with no `partial` on blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`) |
| **Ship-readiness match** | Row 16 verdict aligns with merge-readiness state — `NOT_MERGE_READY` → row FAIL |

Ledger template columns must record: `log_bytes`, `live_invoke` (yes/no), `commit_sha` (or `brownfield_waiver`), `host_agent_attestation`.

---

## 6. Scorer / rescore policy

| Event | Action |
|-------|--------|
| **Default after every row invoke** | Post-invoke rescore: `enterprise_e2e_outcome_row_passes` on row attempt log — **diagnostic**; certification credit requires live strict-clean (§5a) |
| **After harness fix** | `SB_E2E_MATRIX_FORCE=1` on affected row(s), then **live rerun** — rescore alone does **not** bypass install-version registry or grant certification credit |
| **Full re-run same install** | `SB_E2E_MATRIX_FORCE_ALL=1` overrides `.row-pass-registry.json` skip |
| **Evidence PASS + outcome FAIL** | Treat as scorer/harness bug until **live rerun** passes or issue filed — rescoring FAIL→PASS without live rerun is **disqualifying** (E2E-089) |
| **Ledger vs monitor mismatch** | Ledger wins; run `enterprise-e2e-ledger-reconcile.sh` |
| **Rescore-only 22/22** | **Not strict-clean** — Cursor-1 retry2 produced rescored 21–22/22 without live agent work on several rows; void for release sign-off |

**Certification rule:** Only **live matrix invocations** at the current install fingerprint count toward strict-clean and consecutive-round pairs. Rescore may reconcile harness bugs but never substitutes for a missing live session.

Read [OUTCOME-ASSESSMENT-RUBRIC.md](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) before scoring. All **27 criteria** + blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`).

---

## 6a. Install-version row pass registry

**Policy (effective 2026-07-01):** Do **not** repeat any matrix row that has **already passed once** (live TUI + outcome criteria) for the **same SB install fingerprint** within a round or continuation. One clean pass per row per install is sufficient.

### Install fingerprint

Derived at matrix run time as:

```text
<host>@<sb_git_sha12>+<surface_hash12>
```

| Component | Source |
|-----------|--------|
| `host` | `SB_E2E_LIVE_RUNTIME` / `enterprise_e2e_matrix_host` (`claude` \| `codex` \| `cursor`) |
| `sb_git_sha12` | `git -C $SB_ROOT rev-parse --short=12 HEAD` |
| `surface_hash12` | `sha256(hooks/hooks.json_digest[:16] \| package.json version)[:12]` |

Re-install or harness surface change (hooks version bump) produces a **new** fingerprint — rows must be re-run on the new install. Legacy TSV registry `.e2e-matrix-pass-at-version.tsv` (`package@sha`) remains for Cursor track continuity; canonical JSON registry supersedes for strict-clean.

### Registry file

Path: [`.planning/enterprise-e2e/.row-pass-registry.json`](../../.planning/enterprise-e2e/.row-pass-registry.json)

Keyed by `install_fp` → `rows` → `{passed_at, log_ref, outcome_pass, source}`.

### Harness skip behavior

Before row *N*, if registry shows `outcome_pass: true` for current `install_fp`:

| Message | Class | Counts toward 22/22? | `SB_E2E_MATRIX_FAIL_ON_SKIP=1` |
|---------|-------|----------------------|--------------------------------|
| `ROW_ALREADY_PASSED_SAME_INSTALL` | Install-version pass | **Yes** (PASS) after first strict-clean pair @ `install_fp` | **Disqualifying on first host certification** @ install_fp (§5a #5) |
| `SKIP: evidence already present` | Evidence reuse | No (SKIP) | **Fails** when set — never certification credit |

| Override | Effect |
|----------|--------|
| `SB_E2E_MATRIX_FORCE=1` | Re-run despite evidence SKIP; **does not** bypass install-version registry |
| `SB_E2E_MATRIX_FORCE_ALL=1` | Full re-run including registry-passed rows |

### Driver coordination (Round 8 example)

When a live driver (e.g. PID **47290** on `claude@30558b37…`) is mid-batch:

1. **Do not kill** a healthy driver to avoid duplicate TUI spend on rows already in flight.
2. Seed registry for smoke-passed rows (1, 3, 6, 11, 21, 22) **before** next resume launch.
3. On resume after driver exit, rows 3 and 11 (if seeded) emit `ROW_ALREADY_PASSED_SAME_INSTALL` — run only missing rows.

`bash scripts/enterprise-e2e/strict-clean-check.sh` requires install registry **22/22** for current `install_fp` plus ledger reconcile and outcome assessment.

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
| Watchers | Prefer **tmux** durable daemon (`run-enterprise-e2e-matrix.sh` / tmux batch) — **not** `nohup` background shells as primary driver |
| Parent orchestrator | One **`composer-2.5`** background worker (`Task` tool); **never** `composer-2.5-fast` for subagents; resume same worker ID |
| Poll cadence | 60–90s substantive checkpoints |
| **ENOTFOUND / network** | Exponential backoff on poll — transient DNS failures are not auth failures |
| **Stdout buffering** | Cursor headless logs may show **0 B for ~30 min** while agent is working — buffering is normal but **does not** satisfy §5b log floor; wait or fix E2E-086 streaming |
| **Cursor auth** | Keychain / interactive Cursor auth — **not** `CURSOR_API_KEY` for live matrix drivers |
| **Per-row timeouts** | Row **8** (`silver-refactor`): `SB_E2E_ROW8_TIMEOUT=3600`; row **11** (`silver-devops`): `SB_E2E_ROW11_TIMEOUT=5400` (E2E-087) |

Host-isolated artifacts: see [HOST-CONFIG.md](../../.planning/enterprise-e2e/HOST-CONFIG.md).

---

## 9. Cross-agent isolation

When Claude Round 6, Codex, and Cursor run in parallel:

1. **Separate SB git branches** per host — never commit Codex harness to `enterprise-e2e/cursor` or Claude `round6`.
2. **Separate fixture branches** per host — see §4.
3. **Separate locks** — `.e2e-live-test.lock` (Claude), `.e2e-live-test-codex.lock`, `.e2e-live-test-cursor.lock`.
4. **Never** `pkill` another host's monitor/driver PIDs.
5. **Never** remove another host's lock unless that host's driver PID is confirmed dead.
6. **Cursor worktree** when shared clone is dirty on another branch — `enterprise-grade-test-app-cursor` @ `enterprise-e2e/round-N-cursor` ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
7. **Single workspace per host** for SB fixes — test app is matrix CWD only.
8. **Branch guard:** `enterprise_e2e_assert_host_git_branch` in `matrix.sh` / `live-test.sh` — matrix aborts on SB harness branch mismatch.
9. **Cross-host contamination** on shared clone (Codex batch on Cursor branch, wrong `test_app_git_branch`) **voids the round** — reset fixture, verify worktree isolation (E2E-090).

---

## 10. Host execution prompts (per-track)

| Host | Prompt |
|------|--------|
| Codex | [`.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Cursor | [`.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Claude R6 | [`.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md`](../../.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md) |

All tracks **must read this methodology doc** at session start.

---

## 11. Single-pass-at-install-version (Cursor E2E — effective 2026-07-01)

**Policy:** Do **not** repeat any matrix row, ladder rung, or T1 criterion that already **Pass** at the current SB install version. One clean pass per row/criterion is sufficient within and across rounds (Cursor-1 + Cursor-2) when the install version key is unchanged.

**Install version key** (`SB_INSTALL_VERSION_KEY`):

```text
<SB_CURSOR_PLUGIN_VERSION>@<git HEAD short SHA at install-cursor.sh>
```

Example: `0.48.9@e9236365`

| Artifact | Path |
|----------|------|
| Install version file | `${SB_ROOT}/.e2e-cursor-install-version.txt` |
| Row pass registry | `${SB_ROOT}/.e2e-matrix-pass-at-version.tsv` |

Written by `bash scripts/install-cursor.sh` after each install. Harness skip log line:

```text
SKIP: row N already pass @ install <version>
```

**Force overrides** (explicit re-run only):

| Env | Effect |
|-----|--------|
| `SB_E2E_MATRIX_FORCE=1` | Re-run all requested rows |
| `SB_E2E_FORCE_ROW=1` | Re-run despite pass-at-version |

**Release pair unchanged:** 2 consecutive **strict-clean rounds** (Cursor-1 + Cursor-2) still required. Within each round, rows already Pass @ install version are skipped — the round still must complete Phase A→C for any not-yet-passed rows/criteria.

**T1 row 1:** single FORCE run when not already Pass @ version (replaces T1 FORCE×2).

**Cross-round skip:** `matrix.sh` consults `ROUND-CURSOR-*-LEDGER.md` + pass registry; if Cursor-1 row Pass and ledger SB SHA matches current install key, Cursor-2 skips that row.

**First certification @ install_fp:** Single-pass skip applies **only after** the host has completed at least one **live strict-clean** round at that install fingerprint. Prior rescored or inherited-evidence passes do not seed the registry for first certification.

---

## 11a. Cursor E2E harness fixes (E2E-086 – E2E-100)

Operators must understand these fixes — misreading them caused false PASS claims in Cursor-1/Cursor-2 (both **void**; see Appendix D):

| ID | Issue | Fix | Operator implication |
|----|-------|-----|----------------------|
| **E2E-086** | Cursor row logs stayed 0 B — `cursor-agent --print` ignored log file | `tests/live/agents/cursor/agent.sh` headless log streaming | 0 B logs → FAIL until streaming fix verified; check log bytes in §5b |
| **E2E-087** | Rows 2/3/5/8/11 hit 900s timeout | Default 1800s; rows **8→3600s**, **11→5400s** in `matrix.sh` | Extend before declaring timeout FAIL on long workflows |
| **E2E-088** | Outcome rubric false fails (handoff, super, KM, measure) | Scorer updates @ `8feda5fc`+ | Evidence PASS + outcome FAIL → fix harness, then **live rerun** |
| **E2E-089** | Rescore flipped rows to PASS without live agent work | Log resolver + scorer fixes — **rescore ≠ strict-clean** | Rescored 22/22 without live sessions is **void** for release |
| **E2E-090** | Parallel hosts shared one test-app checkout | `hosts.json` per-host `test_app_git_branch` + worktree | Always use host worktree; wrong branch **disqualifies round** |
| **E2E-091** | Row 1 `OUT-CLARIFY-01` false fail on routing-only sessions | `enterprise_e2e_outcome_score_clarify` returns `n/a` when routing evidence present | Routing-only row 1 without clarify is **not** a blocking fail |
| **E2E-092** | Row 6 timeout @ 900s when tmux/shell inherited legacy timeout | `matrix.sh` enforces cursor ≥1800s; `cursor3-real-driver.sh` exports timeout env | Use driver or export `CLAUDE_INTERACTIVE_TIMEOUT=1800` before matrix |
| **E2E-093** | §5b log floor (<2048 B) — cursor-agent `--print` summary-only + harness truncate | `agent.sh` preserves harness prefix, `stream-json` + `stdbuf`; `enterprise_e2e_matrix_finalize_attempt_log` composite transcript when evidence present | Short summary alone does **not** PASS §5b unless composite footer appended after evidence verify |
| **E2E-094** | Row 6 `OUT-ORCH-01` false fail on silver-fast fast-path | `enterprise_e2e_outcome_score_orch` returns `n/a` when row 6 evidence + `silver-fast` state present | Fast-path rows do not require orchestrator parent/worker chain |
| **E2E-095** | Brownfield evidence SKIP without `SB_E2E_MATRIX_FORCE=1` | `cursor3-real-driver.sh` + pipeline driver export `FORCE` + `FORCE_ALL` | First live FORCE on brownfield rows requires explicit force — inherited artifact alone is **not** strict-clean |
| **E2E-096** | Row 10 autonomy scorer false-negative on negated "operator pauses" + prompt `SB OVERRIDE` instruction | Babysitting exclusion + `SB OVERRIDE:` colon-required detector in outcome scorer | Rescore on genuine live log OK; do not rerun row when product delta already committed |
| **E2E-097** | Row 14 `OUT-RELEASE-01` partial — `silver-release` lacks ship-readiness dir | Row 14 uses CHANGELOG + release phase SHIP evidence path | Release workflow ≠ ship-readiness checklist row |
| **E2E-098** | Row 14 `OUT-KM-01` partial — matrix graphify preamble without agentmemory MCP | Matrix graphify preamble + MCP-disabled env → pass | Matrix TUI often disables agentmemory MCP — graphify preamble satisfies KM gate |
| **E2E-099** | Row 15 `OUT-RELEASE-01` partial on `review-triad` | `triad-currency.md` triad evidence path | Review-triad ≠ release workflow — triad artifact chain satisfies gate |
| **E2E-100** | Rows 21–22 internal gates lack attempt logs (<2048 B) | `.cursor3-monitor-loop.sh` exempts internal harness rows | Internal rows verify via parent rows 3/4 markers — no standalone §5b log floor |

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

---

## Appendix C — Anti-faking checklist (operator paste)

Before marking any row PASS in a ledger:

- [ ] Log file **> 2048 B** (or brownfield waiver with file:line)
- [ ] Live invoke (`SB_ENTERPRISE_E2E_LIVE=1`) at current `install_fp` — not rescore-only
- [ ] Fixture **commit SHA** on host branch (or documented brownfield waiver)
- [ ] `enterprise_e2e_outcome_row_passes` — no blocking gate partial
- [ ] Row 16: ship-readiness state matches outcome (not `NOT_MERGE_READY` + PASS)
- [ ] Rows 21–22: parent rows 3/4 live strict-clean @ same `install_fp`
- [ ] Test-app branch = `enterprise-e2e/round-N-{host}` via worktree — not shared clone contamination
- [ ] Host-agent authorship attested — not operator-only routing for implement rows

---

## Appendix D — Cursor track lessons (Rounds Cursor-1/2 — **void**; Cursor-3 REAL canonical)

**Policy (2026-07-03):** Rounds **Cursor-1** and **Cursor-2** are **void** for host certification and release sign-off. Their ledgers, rescored outcome files, install-skip rows, and inherited-evidence passes **must not** be cited as strict-clean certification. The **canonical honest Cursor certification** is **Round Cursor-3 REAL** — [`.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md) — **22/22 strict-clean** under §5a/§5b anti-faking methodology with harness fixes E2E-091–E2E-100.

Documented **disqualifying patterns** from void Cursor-1/Cursor-2 sessions — do not repeat:

| Pattern | Example | Verdict |
|---------|---------|---------|
| **Cursor-1/Cursor-2 round claims** | Any 22/22 or "strict-clean YES" on Cursor-1 or Cursor-2 ledgers | **Void** — superseded by Cursor-3 REAL |
| Inherited baseline PASS | Rows passing on `8482e60` artifacts without live session | **Void** |
| Rescore-only 22/22 | E2E-089 retry2 rescored evidence without live reruns | **Not strict-clean** — **Void** for certification |
| 148 B timeout PASS | Row 4 `silver-bugfix` PASS with 148 B + timeout | **Void** — §5a #3 |
| Install-skip first cert | Cursor-2 rows 2–6, 9–14, 17–20 `evidence_present` skip on first Cursor-2 @ new install | **Void** — install-skip without prior live strict-clean @ same `install_fp` |
| Audit-only row 7 | Verify-only with no product mutation | **Not certified delivery** |
| Wrong fixture branch | R8 Claude rows on `round-8-codex` instead of `round-8-claude` | **Round disqualified** |

**Real certification** (Cursor-3+ only): reset fixture to baseline SHA on `enterprise-e2e/round-N-cursor`, T0 → T1 live row 1 → T2 smoke or one full workflow row with **committed delta**, live FORCE on brownfield rows (`SB_E2E_MATRIX_FORCE=1`), ledger per [`.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md). Harness rescoring (E2E-096/097/099) is permitted **only** on genuine live logs with committed product deltas — never on inherited or rescore-only evidence.
