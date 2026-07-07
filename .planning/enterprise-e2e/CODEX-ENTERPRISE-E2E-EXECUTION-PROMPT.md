# Codex Host — Enterprise E2E Fresh Session Execution Prompt (v4 — single-round release candidate)

**Canonical methodology:** [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) — **read this first**; this prompt is the Codex operator companion, not a substitute.

**Harness:** Shared host-agnostic tree — [SHARED-HARNESS.md](./SHARED-HARNESS.md) · [HOST-CONFIG.md](./HOST-CONFIG.md) · `scripts/enterprise-e2e/`

**Host identity:** OpenAI **Codex TUI** (`codex` CLI) — `$silver:*` slash skills, `codex-interactive-invoke.*` harness.

**Status (2026-07-04):** Codex-1 and Codex-2 are **void** for product certification (pre-seeded baseline). **Codex-3 REAL** @ `f9ed398f` is **CLOSED Pass** and satisfies **single-round release candidate sign-off** ([Appendix F](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md#appendix-f--release-candidate-sign-off-status--codex-host)). **Codex-4 was not executed** — run a new round only when re-certifying a **new** `install_fp` (post-merge sibling session).

**Cross-links:**

- [SHARED-HARNESS.md](./SHARED-HARNESS.md) — deterministic vs live layers, shared `scripts/enterprise-e2e/`
- [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) — **mandatory read before row scoring** (27 criteria + WBS)
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md) — canonical live test runbook
- [CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md](../../docs/testing/CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md) — harness readiness checklist
- [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/main/docs/WORKFLOW_E2E_MATRIX.md) — 22-row prompt cards (test app)

---

## Mission

**Default:** Codex host product certification is **already signed off** via Codex-3 REAL — do **not** start Codex-4 unless re-certifying a **new release candidate** `install_fp` (harness merge, surface hash change, or §11b post-merge sibling session).

**When re-cert is required:** Deliver one strict-clean round @ the new `install_fp` — ladder 8/8 + matrix 22/22 live + §5b product audit + outcome PASS + Phase C green (methodology §3).

**SB git branch:** Harness is on **`main`**. Run matrix drivers from `main` @ current HEAD. Optional: create `enterprise-e2e/codex-roundN` for ledger-only commits; cherry-pick verified fixes to `main` per cherry-pick policy.

**Honest baseline (mandatory):** `09f8d1a` on fixture branch `enterprise-e2e/round-N-codex` — **never** `8482e60`/`826cb5c` pre-seed for product rounds.

```bash
export SB_E2E_TEST_APP_BASELINE_SHA=09f8d1a
export SB_E2E_PRODUCT_WORK_GATE=1
export SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-N-codex   # next round only when re-certing
export SB_E2E_BRANCH=main
```

**Driver template (re-cert only):** `bash .planning/enterprise-e2e/codex-r4-real-driver.sh 1 3 6` (Tier B) then full 22 — or reuse `codex-r3-real-driver.sh` pattern with new ledger.

**Strict-clean** = ALL of:

1. **review-fix-ladder** **8/8** rungs with **2 consecutive clean verify passes** per rung, **0 new issues** (`python3 scripts/review-fix-ladder.py --host codex`)
2. Live matrix **22/22** evidence PASS, **0 new friction/issues** vs baseline
3. **Every row** passes `enterprise_e2e_outcome_row_passes` (no `partial`)
4. Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 (tri-host includes Codex)

Evidence-only PASS or SKIP rows **do not** count strict-clean.

---

## Operational policies (mandatory)

- **Compaction** on context full — **not** `/clear`.
- **No `gsd` references** anywhere (docs, prompts, commits).
- **Single driver** per host; `SB_E2E_MONITOR_AUTO_RESTART=0`; poll-only while batch alive and log growing.
- **Do not kill** healthy driver **<45 min** unless confirmed stuck/dead.
- `RTK_DISABLED=1` for harness/preflight verbatim output.
- **No** `claude auth login/logout` — this track is Codex-only.
- **429 / quota:** retry every **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`); not auth failure.
- Re-run `bash scripts/install-codex.sh --purge-legacy-skills` after every SB harness/hook fix.
- **SB branch:** `main` (harness merged post Codex-3) — verify with `git branch --show-current`; override with `SB_E2E_BRANCH` if using a round-specific ledger branch.
- Recommended tools **opted-in and verified:** Graphify, agentmemory, RTK, Context Mode, Alumnium.

---

## Outcome assessment (mandatory)

**Read** [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) **before scoring any row.**

Score **all 27 criteria** in rubric / `outcome-criteria-registry.json`, including:

- **WBS** decomposition, supervision, verification, validation (`OUT-SUPER-01` meta-supervision loop)
- Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
- Contextual workflow tailoring, verification & validation loops, quality gates, spec-to-release traceability, knowledge management (Graphify + agentmemory JIT retrieval)
- Autonomous delivery: SB drives to completion from vague prompt; `$silver:clarify` when needed — assist-only = FAIL

Any mandatory outcome failure = **row FAIL** = round **not** strict-clean. Run `enterprise_e2e_outcome_row_passes` after each row; re-score after `SB_E2E_MATRIX_FORCE=1`.

### §5b product commit gate (Codex-3 REAL)

When `SB_E2E_PRODUCT_WORK_GATE=1` (default on Codex-3 REAL), **implement rows** must produce a **git commit on the fixture branch** (`enterprise-e2e/round-9-codex` @ baseline `09f8d1a`). Planning-only workflow evidence **without** product code + commit = **row FAIL**.

- Matrix invoke prompts append: *implement real product code and git-commit on fixture branch before ending*.
- Exempt: row 1 (routing), row 15 (triad audit), rows 21–22 (internal inherit).
- Codex parent/orchestrator must **delegate implementation to workers** and ensure workers **commit product deltas** — not stop at `.planning/workflows/*.md` alone.

---

## Deterministic preflight (mandatory before live)

Run all green before `SB_ENTERPRISE_E2E_LIVE=1` matrix launch:

| Phase | Command |
|-------|---------|
| Structural harness | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Host preflight | `bash scripts/run-enterprise-e2e-live-test.sh --host codex --preflight-only` |
| Dry-run matrix | `SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=codex bash scripts/run-enterprise-e2e-matrix.sh` |

---

## Fix loop (SB codebase)

On any friction:

1. **Diagnose** from logs (no guessing).
2. **Fix** in SB repo (`scripts/enterprise-e2e/lib/` — shared across hosts; not test app product code).
3. **Commit** on the Codex host branch (`enterprise-e2e/codex-round1` or `*codex*`); log verified fix in [ENTERPRISE-E2E-CHERRY-PICK.md](../../docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md).
4. **Cherry-pick** verified fixes to `main` per cherry-pick policy.
5. **`graphify update .`** after substantive SB edits; `graphify query` before scoped work.
6. Re-run affected row with **`SB_E2E_MATRIX_FORCE=1`**; then `bash scripts/install-codex.sh --purge-legacy-skills`.

**Baseline:** `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` — **76** unique IDs (0 new for strict-clean). Persist new issues after each fix cycle.

---

## Session workspace

| Role | Path |
|------|------|
| **Session workspace root (SB fixes, harness, ledger)** | `/Users/shafqat/projects/silver-bullet/repo` |
| **SB git branch (Codex harness work)** | `main` (default post Codex-3 merge; optional `enterprise-e2e/codex-round4` for ledger-only) |
| **Codex TUI CWD (matrix rows, Session 0)** | `/Users/shafqat/projects/enterprise-grade-test-app` |

**Never** use the test app as SB workspace root. **Never** use Cursor global config as session root.

**Test app:** Same fixture (`enterprise-grade-test-app`) is OK for all hosts — matrix rows and Session 0 run there. **SB harness commits** stay on the Codex-named branch only; do not use the test app repo for SB harness fixes.

---

## Cross-host isolation (mandatory when Claude Round 6 active)

- **Git branches:** Harness lives on **`main`** post Codex-3 closure. Optional round ledger branch `enterprise-e2e/codex-round4`. **Never** commit Codex harness work to `enterprise-e2e/round6`, `enterprise-e2e/cursor-*`, or Claude branches.
- Do **NOT** remove `.e2e-live-test.lock` unless Round 6 Claude driver is confirmed dead.
- Codex track uses `.e2e-live-test-codex.lock` — never steal Claude's lock.
- Set before matrix/monitor/watch launch (or rely on harness defaults when `SB_E2E_LIVE_RUNTIME=codex`):

```bash
export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-codex-batch.pid
export SB_E2E_MATRIX_MONITOR_PID_FILE=.e2e-matrix-codex-monitor.pid
export SB_E2E_MATRIX_MONITOR_STATUS_FILE=.e2e-matrix-codex-monitor-status.txt
export SB_E2E_TUI_FINDINGS=.e2e-tui-watch-codex-findings.jsonl
export SB_E2E_TUI_OFFSETS=.e2e-tui-watch-codex-offsets.json
export SB_E2E_LIVE_TEST_LOCK_FILE=.e2e-live-test-codex.lock
```

- Never run monitor `pkill` helpers from Claude track against Codex PIDs.
- Never share `.e2e-row*-attempt.log` with Claude — Codex uses `.e2e-row{N}-codex-attempt.log`.
- Pin tmux session `codex-e2e` (not `round6-force`).

TUI protocol: [CODEX-TUI-PROTOCOL.md](./CODEX-TUI-PROTOCOL.md)

---

## Pinned paths (Codex track)

| Resource | Path |
|----------|------|
| SB repo root | `/Users/shafqat/projects/silver-bullet/repo` |
| SB git branch (Codex) | `main` (default) |
| Test app (Codex CWD) | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Codex install script | `/Users/shafqat/projects/silver-bullet/repo/scripts/install-codex.sh` |
| Codex live adapter | `/Users/shafqat/projects/silver-bullet/repo/tests/live/agents/codex/agent.sh` |
| Codex interactive invoke | `/Users/shafqat/projects/silver-bullet/repo/scripts/codex-interactive-invoke.py` (+ `.expect`) |
| Review-fix-ladder resolver | `python3 scripts/review-fix-ladder.py --host codex` |
| Round ledger (Codex-1) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md` |
| Round ledger (Codex-2) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CODEX-2-LEDGER.md` |
| Round gates (Codex-1) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CODEX-1-GATES.md` |
| Round gates (Codex-2) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CODEX-2-GATES.md` |
| Matrix live log | `/Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-codex-live.log` |
| Monitor status | `/Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-codex-monitor-status.txt` |
| TUI watch findings | `/Users/shafqat/projects/silver-bullet/repo/.e2e-tui-watch-codex-findings.jsonl` |
| Outcome rubric | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md` |
| SB issues baseline | `/Users/shafqat/projects/silver-bullet/repo/docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` (**76** unique IDs — 0 new for strict-clean) |
| Cherry-pick policy | `/Users/shafqat/projects/silver-bullet/repo/docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md` |
| Operator prompt (canonical) | `/Users/shafqat/projects/silver-bullet/repo/scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md` |
| Workflow matrix (22 rows) | `/Users/shafqat/projects/enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |

---

## Host-specific setup (Codex)

### Git branch (session start — before install)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_BRANCH=main
cd "$SB_ROOT"
git fetch origin
git checkout main
git pull --ff-only origin main 2>/dev/null || true
git branch --show-current   # must be main (or explicit SB_E2E_BRANCH)
```

### Install & runtime

```bash
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
cd "$SB_ROOT"

# Fresh install from current SB tip after every harness fix:
bash scripts/install-codex.sh --purge-legacy-skills
```

### Auth & env (no Claude login)

- **Codex API key** via `OPENAI_API_KEY` or Codex config (`~/.codex/config.toml` / `~/.Codex/config.toml`).
- **Do NOT** run `claude auth login/logout` — this track is Codex-only.
- **Do NOT** conflate Codex desktop thread affinity: unset `CODEX_THREAD_ID`, `CODEX_INTERNAL_ORIGINATOR_OVERRIDE` for live matrix (`codex-interactive-invoke.py` strips these).
- **`RTK_DISABLED=1`** for harness/preflight verbatim output.
- **`SB_E2E_MONITOR_AUTO_RESTART=0`**
- On **429 / quota**: retry every **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`); not auth failure.

### Recommended tools (opt in on both repos)

Set `recommended_tools.<tool>.enabled_by_user: true` in each repo's `.silver-bullet.json`:

| Tool | Role |
|------|------|
| **Graphify** | `graphify query` before each row; `graphify update .` after SB edits |
| **agentmemory** | MCP session evidence; retrieve via Graphify |
| **RTK** | Shell compression (operator sessions) |
| **Context Mode** | MCP / large-file compression |
| **Alumnium** | Browser/visual MCP for UI workflows |

### Bootstrap preflight (before Phase A)

```bash
cd "$SB_ROOT"
export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_AGENT=codex

# Structural wiring:
bash tests/e2e-live/hook-delivery-preflight.sh   # SB_LIVE_AGENT=codex when set
bash scripts/install-codex.sh --purge-legacy-skills

# Tri-host smoke for THIS host (pragmatic gate before full matrix):
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host codex

# Test app sanity:
cd "$SB_TEST_ENTERPRISE_APP_ROOT" && npm test

# Verify Codex CLI:
codex --version
python3 scripts/review-fix-ladder.py --host codex --json | head
```

### Session 0 gate

Matrix launch requires Session 0 unless waived:

- Ledger Session 0 **Pass** for Graphify + agentmemory, **or**
- Fixture `.silver-bullet.json` has graphify + agentmemory `enabled_by_user: true`.

Waiver (document reason): `SB_E2E_SESSION0_SKIP=1` + `SB_E2E_SESSION0_SKIP_REASON=...`

**Session 0 in Codex TUI:**

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
codex   # CWD = test app
```

In Codex TUI: run `$silver:init` (or `/silver:init` per host skill alias), opt in Graphify + agentmemory, `graphify update .` in test app, then stop.

---

## Phase A — review-fix-ladder (Codex host)

Run **8 rungs** with **2 consecutive clean verify passes** each before starting Phase B.

```bash
cd "$SB_ROOT"
export SILVER_BULLET_RUNTIME=codex
export RTK_DISABLED=1

# Resolve rung model/reasoning for Codex:
python3 scripts/review-fix-ladder.py --host codex

# Live ladder smoke (structural):
SILVER_BULLET_RUNTIME=codex bash tests/live/test-live-review-fix-ladder-smoke.sh

# Full ladder (when wiring verified):
SILVER_BULLET_RUNTIME=codex bash tests/live/test-live-review-fix-ladder-full-ladder.sh
```

In Codex TUI (SB repo CWD for ladder fixes): invoke `$silver:review-fix-ladder` per skill routing. Record each rung in `ROUND-CODEX-1-LEDGER.md` ladder section.

**Gate:** 8/8 rungs complete, 0 new issues in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`.

---

## Phase B — 22-row matrix (Codex host)

### Phase B status: **READY** (harness M1–M6 on `enterprise-e2e/multi-host`)

Matrix runner honors `SB_E2E_LIVE_RUNTIME=codex`, routes via `tests/live/agents/codex/agent.sh`, host-isolated lock/logs/PIDs, and `$silver:*` route translation.

**Pre-matrix validation gate:**

```bash
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
```

1. **Wire host runtime** (defaults apply when only `SB_E2E_LIVE_RUNTIME=codex` is set):

```bash
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-codex-live.log"
export SB_ENTERPRISE_E2E_LIVE=1
export RTK_DISABLED=1
```

2. **Live entrypoint** (preferred):

```bash
SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 \
  bash scripts/run-enterprise-e2e-live-test.sh --host codex --resume
```

3. **Direct matrix runner:**

```bash
cd "$SB_ROOT"
SB_E2E_LIVE_RUNTIME=codex SILVER_BULLET_RUNTIME=codex \
  SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md \
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh

# tmux detached (export SB_ROOT inside bash -lc):
tmux new-session -d -s codex-e2e bash -lc '
  export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
  cd "$SB_ROOT" && \
  export SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex \
    SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md RTK_DISABLED=1 && \
  bash scripts/run-enterprise-e2e-live-test.sh --host codex --resume
'
```

4. **After every SB harness fix:** follow [Fix loop](#fix-loop-sb-codebase) — `install-codex.sh` + `SB_E2E_MATRIX_FORCE=1` on failed row.

5. Cherry-pick verified fixes to `main` per [ENTERPRISE-E2E-CHERRY-PICK.md](../../docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md).

**Remaining (P2):** Codex-specific expect parity suite (`tests/enterprise-e2e-live/*codex*`); one full row live CI fixture (M7).

### Matrix row template (Codex TUI — test app CWD)

```
Enterprise E2E matrix row {ROW} — Codex host track.

Use the Silver Bullet orchestrator — do not implement product changes inline in the parent session unless the workflow requires it.

User request (natural language):
{PROMPT_CARD from WORKFLOW_E2E_MATRIX.md}

Follow the routed workflow to completion. Record progress in .planning/workflows/ per SB conventions.
When done, summarize: route invoked, skills recorded, artifacts created, test status.
```

Rows **21–22** run inside parent sessions (rows 3 and 4). Row **1** is routing-only.

### Dual-role monitoring

| Shell | Role | Command |
|-------|------|---------|
| **A — Drive** | Matrix batch | `bash scripts/run-enterprise-e2e-live-test.sh --host codex --resume` |
| **B — Monitor** | Batch health | Full env block from [CODEX-TUI-PROTOCOL.md](./CODEX-TUI-PROTOCOL.md) + `bash scripts/monitor-enterprise-e2e-matrix.sh &` |
| **C — Watch** | TUI friction | Same env block + `bash scripts/watch-enterprise-e2e-tui.sh &` |

Monitor PID check: `kill -0 "$(cat .e2e-matrix-codex-batch.pid)"` (not `.e2e-matrix-batch.pid`).

---

## Phase C — gates (outcome, validation, RCS, tri-host)

Run after matrix 22/22 evidence PASS:

```bash
cd "$SB_ROOT"
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md
export RTK_DISABLED=1

# Outcome harness:
bash tests/scripts/test-outcome-assessment.sh

# Full test suite:
bash tests/run-all-tests.sh

# Validation overlay (pre-matrix should already be green):
bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md \
  bash scripts/run-enterprise-e2e-validation-overlay.sh --live

# Pre-release overlay + Codex tri-host:
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host codex
export SB_E2E_RCS_TRIHOST=full  # after --host smoke passes

# Ledger reconcile:
bash scripts/lib/enterprise-e2e-ledger-reconcile.sh .e2e-matrix-codex-live.log

# RCS score (set overlay pass when dry-run green):
SB_E2E_RCS_TRIHOST=full SB_E2E_RCS_VALIDATION_OVERLAY=pass RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh
```

**Release candidate gate:** One strict-clean round @ release candidate `install_fp` satisfies Codex host sign-off. Codex-3 REAL @ `f9ed398f` is the canonical certifying round — see [ROUND-CODEX-3-GATES.md](./ROUND-CODEX-3-GATES.md) and methodology Appendix F.

---

## Single-round release candidate gate (Codex host)

**Do not tag or sign off** a **new** SB release candidate until **one** strict-clean round passes all gates @ that candidate's `install_fp`:

| Gate | Requirement |
|------|-------------|
| Tier A | All structural checks green (§3) |
| Tier B | Live smoke rows **1, 3, 6** PASS |
| Phase A | review-fix-ladder **8/8** |
| Phase B | Matrix **22/22** live + §5b per row |
| Phase C | `test-outcome-assessment.sh`, `run-all-tests.sh`, overlays, ledger reconcile, RCS ≥ 85 |
| Product audit | Host-specific `*-TEST-APP-PRODUCT-AUDIT.md` — committed deltas on honest `09f8d1a` baseline |

**Codex-3 REAL (closed):** All gates **PASS** @ `f9ed398f` — [ROUND-CODEX-3-LEDGER.md](./ROUND-CODEX-3-LEDGER.md). No Codex-4 required under current policy.

**Re-cert trigger:** New `install_fp` after `install-codex.sh` on updated `main` — re-run full Phase A→C; prior Codex-3 PASS does **not** carry forward.

**Deprecated:** 2/2 consecutive strict-clean pair (Codex-1 + Codex-2 model) — superseded 2026-07-04. `enterprise-e2e-consecutive-rounds-check.sh` remains for historical Cursor tracks only.

---

## Codex TUI protocol

Full checklist: [CODEX-TUI-PROTOCOL.md](./CODEX-TUI-PROTOCOL.md)

### Invoke patterns

| Action | Codex TUI |
|--------|-----------|
| Bootstrap | `$silver:init` in test app CWD |
| Router | `$silver` or natural-language → orchestrator |
| Clarify | `$silver:clarify` when ambiguous |
| Ladder | `$silver:review-fix-ladder` in SB repo CWD |
| Feature/UI/etc. | `$silver:feature`, `$silver:ui`, … per matrix card |

### Harness spawn

Matrix driver should use:

- `tests/live/agents/codex/agent.sh` — `agent_preflight`, `agent_cli_path`, transcript capture
- `scripts/codex-interactive-invoke.py` — PTY session, prompt injection, quiet-timeout detection
- Transcript dir: `${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/codex/transcripts}`

### Friction watch (during each row)

Read **during** each row, not only at row end:

- `.e2e-row{N}-attempt.log`, `.e2e-matrix-codex-live.log`, monitor status, Codex expect transcript
- Watch for: 0-token turns, MCP auth banners, skill picker failures, `(?s)` regex/Tcl expect failures, `install-codex` hangs, orchestrator parent deny, stale plugin cache, duplicate subagents, WiFi stalls, stub/skipped rows, outcome FAIL with evidence PASS
- **3 idle polls on same row → investigate** (do not silently poll)
- **Token counts:** record per-row telemetry (input/output/total when available); do not gate on cost claims

### Graphify + agentmemory (per row)

Before each row: `graphify query "<workflow slug> routes hooks skills orchestrator"` — record in ledger `graphify_query_ref`.

After each row: agentmemory export — record in `agentmemory_export_ref`.

---

## Parent orchestrator ops (this chat)

- Run **ONE** long-lived background worker (`Task`, `run_in_background: true`, **`model: composer-2.5` ONLY** — never `composer-2.5-fast`).
- **Resume the same worker ID** across turns; do not spawn parallel matrix operators.
- Relay **every poll cycle (~60–90s)** — substantive checkpoint, NOT "still running"; minimum table:

| Driver PID alive? | Active row/skill | Last meaningful TUI lines | Evidence PASS count | Outcome PASS count | Friction this cycle | Action taken |
|-------------------|------------------|---------------------------|---------------------|--------------------|---------------------|--------------|

- **On row complete:** report evidence PASS/FAIL + full outcome checklist (all 27 criteria) + friction summary + fix SHA (if any).
- **Never pause for operator.** On blockers: follow [Fix loop](#fix-loop-sb-codebase) — do not wait for user input.
- **User-pause exception:** if user explicitly requests pause → finish current poll turn, write checkpoint to ledger, then stop.
- **Single driver:** poll-only while batch alive and log growing; no duplicate monitors/drivers.
- **Do not kill** healthy driver **<45 min** unless confirmed stuck/dead.
- **Token counts:** track as telemetry data per row (do not block on marketing "10× cost" claims).

---

## Strict-clean criteria (Codex track)

Same as **§Mission** above, with Codex-specific substitutions:

- `install-codex.sh` instead of `install-claude.sh`
- `$silver:*` skills instead of `/silver:*` slash commands
- Ledger: `ROUND-CODEX-1-LEDGER.md` / `ROUND-CODEX-2-LEDGER.md`
- Log: `.e2e-matrix-codex-live.log`

---

## Known harness gaps + operator responsibilities

Shared harness (`enterprise-e2e/multi-host`) wires `--host`, `SB_E2E_LIVE_RUNTIME`, host-isolated paths, and dry-run for all hosts. Remaining operator responsibilities:

| Gap | Operator action |
|-----|-----------------|
| Codex-specific TUI friction | Adapt patterns in [CODEX-TUI-PROTOCOL.md](./CODEX-TUI-PROTOCOL.md); file SB issues |
| Codex runtime state dir | Set `SB_RUNTIME_STATE_DIR` when not using `~/.codex/.silver-bullet` |
| Session 0 TUI-only path | Programmatic opt-in when TUI unavailable (same as Claude) |
| Outcome re-score per row | Run `enterprise_e2e_outcome_row_passes` after each row FORCE retry |

**File issues** in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`. **Implement host wiring** in `scripts/enterprise-e2e/lib/adapters/codex.sh` — not test app product code.

---

## Resume first actions (§H)

0. **Verify SB branch:** `cd "$SB_ROOT" && git checkout enterprise-e2e/codex-round1` (or your `*codex*` branch); `git branch --show-current` must contain `codex` — never resume harness work on `enterprise-e2e/round6` or Cursor branches.
1. **Read** current round ledger ([ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md) or Round 2); note active row and last checkpoint.
2. **Verify driver:** `kill -0 "$(cat .e2e-matrix-codex-batch.pid 2>/dev/null)" 2>/dev/null || echo "driver dead"`.
3. **If dead:** clear **host lock only** — `rm -f .e2e-live-test-codex.lock` (never `.e2e-live-test.lock` while Claude R6 may be live); single `--resume` relaunch (tmux if no PTY).
4. **If alive:** poll + friction watch only — **no second driver**.
5. **Post first substantive checkpoint within 90s** of session start.
6. Continue until round strict-clean + Phase C; then `bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host codex`.

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_BRANCH=enterprise-e2e/codex-round1
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-codex-live.log"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SESSION0_SKIP=1   # only if Session 0 already Pass in ledger
export RTK_DISABLED=1
cd "$SB_ROOT"
git fetch origin && git checkout "$SB_E2E_BRANCH" || git checkout -b "$SB_E2E_BRANCH" origin/main
git branch --show-current   # must contain codex

# If dead — host lock only, single relaunch:
rm -f .e2e-live-test-codex.lock
tmux new-session -d -s codex-e2e bash -lc '
  export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
  cd "$SB_ROOT" && SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex \
    SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md \
    SB_E2E_MATRIX_LOG=.e2e-matrix-codex-live.log RTK_DISABLED=1 \
    bash scripts/run-enterprise-e2e-matrix.sh --resume
'

# Poll (no second driver while batch alive):
tail -f .e2e-matrix-codex-live.log
tail -f .e2e-matrix-codex-monitor-status.txt
```

---

## One-liner (fresh session copy-paste)

> **Self-contained Codex operator prompt** — paste only this file for fresh sessions (no separate addendum). SB `/Users/shafqat/projects/silver-bullet/repo` on branch **`enterprise-e2e/codex-round1`** (`*codex*` only — never `round6`/Cursor), TUI CWD `/Users/shafqat/projects/enterprise-grade-test-app`, `--host codex`, **2 consecutive strict-clean rounds** (Codex-1→2). One `composer-2.5` background operator, poll 60–90s, checkpoint within 90s on resume. Read OUTCOME-ASSESSMENT-RUBRIC before row scoring (27 + WBS). Deterministic preflight: structural suite + outcome harness + `--preflight-only` + dry-run matrix (see §Deterministic preflight). Fix loop: diagnose→commit on codex branch→cherry-pick to main→graphify→FORCE; baseline 76 issues. Host lock `.e2e-live-test-codex.lock` only. Consecutive rounds: `enterprise-e2e-consecutive-rounds-check.sh --host codex`. Compaction not `/clear`; no `gsd`.
