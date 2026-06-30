# Codex Host — Enterprise E2E Fresh Session Execution Prompt (v2)

**Harness:** Shared host-agnostic tree — [SHARED-HARNESS.md](./SHARED-HARNESS.md) · [HOST-CONFIG.md](./HOST-CONFIG.md) · `scripts/enterprise-e2e/`

**Host identity:** OpenAI **Codex TUI** (`codex` CLI) — `$silver:*` slash skills, `codex-interactive-invoke.*` harness.

**Parallel track:** Runs **in parallel** with ongoing Claude [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — this is the **Codex host track**, not a 5-row smoke.

**Cross-links (read first):**

- [SHARED-HARNESS.md](./SHARED-HARNESS.md) — deterministic vs live layers, shared `scripts/enterprise-e2e/`
- [OPERATIONAL-ADDENDUM.md](./OPERATIONAL-ADDENDUM.md) — cross-host strict-clean ops
- [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — parent orchestrator ops (Claude parallel track)
- [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) — per-row/session scoring; blocking autonomy gates
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md) — canonical live test runbook
- [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/main/docs/WORKFLOW_E2E_MATRIX.md) — 22-row prompt cards (test app)

---

## Mission

Deliver **2 consecutive strict-clean rounds** on the **Codex host track** (Round Codex-1, then Round Codex-2). Strict-clean criteria match [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §A — adapted for Codex TUI instead of Claude TUI.

**Strict-clean** = ALL of:

1. **review-fix-ladder** **8/8** rungs with **2 consecutive clean verify passes** per rung, **0 new issues** (`python3 scripts/review-fix-ladder.py --host codex`)
2. Live matrix **22/22** evidence PASS, **0 new friction/issues** vs baseline
3. **Every row** passes `enterprise_e2e_outcome_row_passes` (no `partial`)
4. Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 (tri-host includes Codex)

Evidence-only PASS or SKIP rows **do not** count strict-clean.

---

## Session workspace

| Role | Path |
|------|------|
| **Session workspace root (SB fixes, harness, ledger)** | `/Users/shafqat/projects/silver-bullet/repo` |
| **Codex TUI CWD (matrix rows, Session 0)** | `/Users/shafqat/projects/enterprise-grade-test-app` |

**Never** use the test app as SB workspace root. **Never** use Cursor global config as session root.

---

## Cross-host isolation (mandatory when Claude Round 6 active)

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

### Install & runtime

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
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

4. **After every SB harness fix:** `bash scripts/install-codex.sh --purge-legacy-skills` then `SB_E2E_MATRIX_FORCE=1` on failed row.

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

**Release pair:** Round Codex-1 strict-clean + Round Codex-2 strict-clean (consecutive) before Codex host release sign-off.

---

## Two-round release gate (Codex host)

**Do not tag or sign off** until **both** rounds are strict-clean **back-to-back** (Round Codex-2 immediately follows a strict-clean Round Codex-1 — no intervening dirty round or skipped Phase A–C).

| Step | Action |
|------|--------|
| 1 | Complete **Round Codex-1** Phases A → B → C; set `Round clean? = Pass` in [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md). |
| 2 | Update [ROUND-CODEX-1-GATES.md](./ROUND-CODEX-1-GATES.md): all gates green including **2 consecutive strict clean rounds = PENDING (1/2)**. |
| 3 | **Fresh Round Codex-2:** copy ledger template → [ROUND-CODEX-2-LEDGER.md](./ROUND-CODEX-2-LEDGER.md); reset matrix log (archive Codex-1 log); re-run **full** Phase A (ladder 8/8 × 2 verify) + Phase B (22/22) + Phase C. |
| 4 | Pin `SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-2-LEDGER.md` for Round 2 only. |
| 5 | After Round Codex-2 strict-clean: update [ROUND-CODEX-2-GATES.md](./ROUND-CODEX-2-GATES.md) — **2 consecutive strict clean rounds = PASS (2/2)**. |
| 6 | **Release readiness:** both gate files show Round N strict-clean + consecutive pair PASS; RCS ≥ 85 with `SB_E2E_RCS_TRIHOST=full`; pre-release overlay dry-run green. |

**Failure between rounds:** If Round Codex-2 is not strict-clean, the pair resets — fix SB, re-run Round Codex-2 from Phase A (do not claim release until a **new** consecutive pair completes).

**Cross-round check (manual until harness script exists):**

```bash
grep -E 'Round clean\? \| \*\*Pass\*\*|2 consecutive strict clean rounds \| \*\*PASS \(2/2\)\*\*' \
  .planning/enterprise-e2e/ROUND-CODEX-{1,2}-GATES.md
```

Harness does **not** auto-enforce the pair — operator + gate files are authoritative ([ROUND-N-GATES.md](./ROUND-N-GATES.md) row **2 consecutive strict clean rounds**).

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

### Graphify + agentmemory (per row)

Before each row: `graphify query "<workflow slug> routes hooks skills orchestrator"` — record in ledger `graphify_query_ref`.

After each row: agentmemory export — record in `agentmemory_export_ref`.

---

## Parent orchestrator ops (this chat)

Mirror [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §B–§G:

- Run **ONE** long-lived background worker (`Task`, `run_in_background: true`, **`model: composer-2.5` ONLY** — never `composer-2.5-fast`).
- **Resume the same worker ID** across turns; do not spawn parallel matrix operators.
- Relay **every poll cycle (~60–90s)** — substantive checkpoint with minimum table:

| Driver PID alive? | Active row/skill | Last meaningful TUI lines | Evidence PASS count | Outcome PASS count | Friction this cycle | Action taken |
|-------------------|------------------|---------------------------|---------------------|--------------------|---------------------|--------------|

- **Never pause for operator.** On blockers: diagnose → fix SB → cherry-pick → re-run affected row.
- **Single driver:** poll-only while batch alive and log growing; no duplicate monitors/drivers.
- **Do not kill** healthy driver **<45 min** unless confirmed stuck/dead.
- On friction: diagnose from logs → fix in SB repo → `install-codex.sh` → `graphify update .` → `SB_E2E_MATRIX_FORCE=1` on affected row → persist new issues (0 new for strict-clean).

---

## Strict-clean criteria (Codex track)

Same as [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §A, with Codex-specific substitutions:

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
| Codex runtime state dir | Set `SB_RUNTIME_STATE_DIR` when not using `~/.claude/.silver-bullet` |
| Session 0 TUI-only path | Programmatic opt-in when TUI unavailable (same as Claude) |
| Outcome re-score per row | Run `enterprise_e2e_outcome_row_passes` after each row FORCE retry |

**File issues** in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`. **Implement host wiring** in `scripts/enterprise-e2e/lib/adapters/codex.sh` — not test app product code.

---

## Resume commands (Codex track)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-codex-live.log"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SESSION0_SKIP=1   # only if Session 0 already Pass in ledger
export RTK_DISABLED=1
cd "$SB_ROOT"

# 1. Read ledger + verify driver alive:
kill -0 "$(cat .e2e-matrix-codex-batch.pid 2>/dev/null)" 2>/dev/null || echo "driver dead"

# 2. If dead: clear stale lock, single relaunch (tmux if no PTY):
rm -f .e2e-live-test.lock
tmux new-session -d -s codex-e2e bash -lc '
  cd "$SB_ROOT" && SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex \
    SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md \
    SB_E2E_MATRIX_LOG=.e2e-matrix-codex-live.log RTK_DISABLED=1 \
    bash scripts/run-enterprise-e2e-matrix.sh --resume
'

# 3. Poll (no second driver while batch alive):
tail -f .e2e-matrix-codex-live.log
tail -f .e2e-matrix-codex-monitor-status.txt

# 4. Preflight only:
RTK_DISABLED=1 SILVER_BULLET_RUNTIME=codex bash tests/e2e-live/hook-delivery-preflight.sh

# 5. Outcome harness verify:
RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh
```

---

## One-liner (fresh session copy-paste)

> Codex enterprise E2E v2 (shared harness `scripts/enterprise-e2e/`): **2 consecutive strict-clean rounds** (Codex-1→2). SB `/Users/shafqat/projects/silver-bullet/repo`, TUI CWD `/Users/shafqat/projects/enterprise-grade-test-app`, `--host codex` or `SB_E2E_LIVE_RUNTIME=codex`, ledger `ROUND-CODEX-{1,2}-LEDGER.md`, log `.e2e-matrix-codex-live.log`. One `composer-2.5` background operator, poll 60–90s. Each round: ladder 8/8×2 verify → matrix 22/22 → Phase C outcome+RCS. Deterministic preflight: `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh`. Fix shared `enterprise-e2e/lib/` not forks; parallel Claude R6 — not smoke.
