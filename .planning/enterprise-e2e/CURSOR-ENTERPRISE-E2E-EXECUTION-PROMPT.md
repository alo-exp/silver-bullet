# Cursor Host — Enterprise E2E Fresh Session Execution Prompt (v2)

**Harness:** Shared host-agnostic tree — [SHARED-HARNESS.md](./SHARED-HARNESS.md) · [HOST-CONFIG.md](./HOST-CONFIG.md) · `scripts/enterprise-e2e/`

**Host identity:** **Cursor `agent` TUI** (`cursor-agent` or `agent` CLI) — rules/skills + orchestrator parent mode.

**Parallel track:** Runs **in parallel** with ongoing Claude [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — this is the **Cursor host track**, not a 5-row smoke.

**Cross-links (read first):**

- [SHARED-HARNESS.md](./SHARED-HARNESS.md) — deterministic vs live layers, shared `scripts/enterprise-e2e/`
- [OPERATIONAL-ADDENDUM.md](./OPERATIONAL-ADDENDUM.md) — cross-host strict-clean ops
- [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — parent orchestrator ops (Claude parallel track)
- [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) — per-row/session scoring; blocking autonomy gates
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md) — canonical live test runbook
- [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/main/docs/WORKFLOW_E2E_MATRIX.md) — 22-row prompt cards (test app)

---

## Mission

Deliver **2 consecutive strict-clean rounds** on the **Cursor host track** (Round Cursor-1, then Round Cursor-2). Strict-clean criteria match [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §A — adapted for Cursor `agent` TUI instead of Claude TUI.

**Strict-clean** = ALL of:

1. **review-fix-ladder** **8/8** rungs with **2 consecutive clean verify passes** per rung, **0 new issues** (`python3 scripts/review-fix-ladder.py --host cursor`)
2. Live matrix **22/22** evidence PASS, **0 new friction/issues** vs baseline
3. **Every row** passes `enterprise_e2e_outcome_row_passes` (no `partial`)
4. Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 (tri-host includes Cursor)

Evidence-only PASS or SKIP rows **do not** count strict-clean.

---

## Session workspace

| Role | Path |
|------|------|
| **Session workspace root (SB fixes, harness, ledger)** | `/Users/shafqat/projects/silver-bullet/repo` |
| **Cursor agent TUI CWD (matrix rows, Session 0)** | `/Users/shafqat/projects/enterprise-grade-test-app` |

**Never** use the test app as SB workspace root. Operator parent sessions use SB repo root per silver-orchestrator rules.

**Supervisor:** Cursor Composer (parent orchestrator with `Task` tool). Matrix child is `cursor-agent` CLI — Codex TUI cannot spawn `Task`.

---

## Cross-host isolation (mandatory when Claude Round 6 active)

- Do **NOT** remove `.e2e-live-test.lock` unless Round 6 Claude driver is confirmed dead.
- Cursor track uses `.e2e-live-test-cursor.lock`.
- Set before matrix/monitor/watch (or rely on harness defaults when `SB_E2E_LIVE_RUNTIME=cursor`):

```bash
export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-cursor-batch.pid
export SB_E2E_MATRIX_MONITOR_PID_FILE=.e2e-matrix-cursor-monitor.pid
export SB_E2E_MATRIX_MONITOR_STATUS_FILE=.e2e-matrix-cursor-monitor-status.txt
export SB_E2E_TUI_FINDINGS=.e2e-tui-watch-cursor-findings.jsonl
export SB_E2E_TUI_OFFSETS=.e2e-tui-watch-cursor-offsets.json
export SB_E2E_LIVE_TEST_LOCK_FILE=.e2e-live-test-cursor.lock
```

- Never `pkill` Claude children from Cursor monitor.
- Row logs: `.e2e-row{N}-cursor-attempt.log` only.
- tmux session: `cursor-e2e` (not `round6-force`).

TUI protocol: [CURSOR-TUI-PROTOCOL.md](./CURSOR-TUI-PROTOCOL.md)

---

## Pinned paths (Cursor track)

| Resource | Path |
|----------|------|
| SB repo root | `/Users/shafqat/projects/silver-bullet/repo` |
| Test app (agent CWD) | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Cursor install script | `/Users/shafqat/projects/silver-bullet/repo/scripts/install-cursor.sh` |
| Cursor live adapter | `/Users/shafqat/projects/silver-bullet/repo/tests/live/agents/cursor/agent.sh` |
| Cursor CLI smoke (pre-release) | `/Users/shafqat/projects/silver-bullet/repo/scripts/pre-release-cursor-cli-smoke.sh` |
| Review-fix-ladder resolver | `python3 scripts/review-fix-ladder.py --host cursor` |
| Round ledger (Cursor-1) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md` |
| Round ledger (Cursor-2) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CURSOR-2-LEDGER.md` |
| Round gates (Cursor-1) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CURSOR-1-GATES.md` |
| Round gates (Cursor-2) | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-CURSOR-2-GATES.md` |
| Matrix live log | `/Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-cursor-live.log` |
| Monitor status | `/Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-cursor-monitor-status.txt` |
| TUI watch findings | `/Users/shafqat/projects/silver-bullet/repo/.e2e-tui-watch-cursor-findings.jsonl` |
| Outcome rubric | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md` |
| SB issues baseline | `/Users/shafqat/projects/silver-bullet/repo/docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` (**76** unique IDs — 0 new for strict-clean) |
| Cherry-pick policy | `/Users/shafqat/projects/silver-bullet/repo/docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md` |
| Operator prompt (canonical) | `/Users/shafqat/projects/silver-bullet/repo/scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md` |
| Workflow matrix (22 rows) | `/Users/shafqat/projects/enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |

---

## Host-specific setup (Cursor)

### Install & runtime

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
cd "$SB_ROOT"

# Fresh install from current SB tip after every harness fix:
bash scripts/install-cursor.sh
# Or public release path:
# bash scripts/install-cursor.sh --public-release
```

### Auth & env

- **Cursor API key** via `CURSOR_API_KEY` env var (preferred for headless/matrix — matches `pre-release-cursor-cli-smoke.sh`).
- **Or** interactive login: `cursor-agent login` / `agent login` — verify with `cursor-agent status` (logged-in account details).
- **Pre-release smoke pattern:** `AGENT_CLI_CREDENTIAL_STORE=memory` + `CURSOR_API_KEY` — never touches macOS Keychain during automated runs.
- **Do NOT** run `claude auth login/logout` — this track is Cursor-only.
- **`RTK_DISABLED=1`** for harness/preflight verbatim output.
- **`SB_E2E_MONITOR_AUTO_RESTART=0`**
- On **429 / quota**: retry every **60s**; not auth failure.

### Subagent model policy (non-negotiable)

- Parent orchestrator and enterprise E2E workers: **`model: composer-2.5` ONLY** for all Task/subagent delegations.
- **Never** `composer-2.5-fast` for subagent work.
- Ladder nominal slugs from `review-fix-ladder.py --host cursor` apply to **Cursor agent TUI** matrix sessions; Task subagents stay on `composer-2.5`.

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
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_AGENT=cursor

# Structural wiring:
bash tests/e2e-live/hook-delivery-preflight.sh

# Install + hooks:
bash scripts/install-cursor.sh

# Cursor CLI smoke (API key isolation — no Keychain):
CURSOR_API_KEY="${CURSOR_API_KEY:?set CURSOR_API_KEY}" \
  AGENT_CLI_CREDENTIAL_STORE=memory \
  RTK_DISABLED=1 bash scripts/pre-release-cursor-cli-smoke.sh

# Tri-host smoke for THIS host:
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host cursor

# Test app sanity:
cd "$SB_TEST_ENTERPRISE_APP_ROOT" && npm test

# Verify agent CLI:
cursor-agent --version || agent --version
python3 scripts/review-fix-ladder.py --host cursor --json | head
```

### Session 0 gate

Matrix launch requires Session 0 unless waived:

- Ledger Session 0 **Pass** for Graphify + agentmemory, **or**
- Fixture `.silver-bullet.json` has graphify + agentmemory `enabled_by_user: true`.

Waiver (document reason): `SB_E2E_SESSION0_SKIP=1` + `SB_E2E_SESSION0_SKIP_REASON=...`

**Session 0 in Cursor agent TUI:**

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
agent -p "Run silver init for this project" --workspace .
# Or open Cursor IDE Composer in-session (SB_LIVE_CURSOR_IN_SESSION=1)
```

Opt in Graphify + agentmemory, `graphify update .` in test app, confirm hooks via `bash scripts/install-cursor.sh --merge-hooks-only` if needed.

---

## Phase A — review-fix-ladder (Cursor host)

Run **8 rungs** with **2 consecutive clean verify passes** each before starting Phase B.

```bash
cd "$SB_ROOT"
export SILVER_BULLET_RUNTIME=cursor
export RTK_DISABLED=1

# Resolve rung model/reasoning for Cursor:
python3 scripts/review-fix-ladder.py --host cursor

# Live ladder smoke (structural):
SILVER_BULLET_RUNTIME=cursor bash tests/live/test-live-review-fix-ladder-smoke.sh

# Full ladder (strict-clean requires live turns, not resolver-only):
SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0 CURSOR_API_KEY="$CURSOR_API_KEY" \
  SILVER_BULLET_RUNTIME=cursor bash tests/live/test-live-review-fix-ladder-full-ladder.sh
```

In Cursor agent TUI (SB repo CWD for ladder fixes): invoke review-fix-ladder skill per SB routing. Record each rung in `ROUND-CURSOR-1-LEDGER.md` ladder section.

**Gate:** 8/8 rungs complete, 0 new issues in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`.

---

## Phase B — 22-row matrix (Cursor host)

### Phase B status: **READY** (harness M1–M6 on `enterprise-e2e/multi-host`)

Matrix runner honors `SB_E2E_LIVE_RUNTIME=cursor`, routes via `tests/live/agents/cursor/agent.sh`, host-isolated artifacts.

**Pre-matrix validation gate:**

```bash
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
```

1. **Wire host runtime:**

```bash
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-cursor-live.log"
export SB_ENTERPRISE_E2E_LIVE=1
export RTK_DISABLED=1
export CURSOR_API_KEY="${CURSOR_API_KEY:?}"
export AGENT_CLI_CREDENTIAL_STORE=memory
```

2. **Live entrypoint** (preferred):

```bash
SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 \
  bash scripts/run-enterprise-e2e-live-test.sh --host cursor --resume
```

3. **Direct matrix runner:**

```bash
cd "$SB_ROOT"
SB_E2E_LIVE_RUNTIME=cursor SILVER_BULLET_RUNTIME=cursor \
  CURSOR_API_KEY="$CURSOR_API_KEY" AGENT_CLI_CREDENTIAL_STORE=memory \
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh

tmux new-session -d -s cursor-e2e bash -lc '
  export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
  cd "$SB_ROOT" && \
  export SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor \
    CURSOR_API_KEY="$CURSOR_API_KEY" AGENT_CLI_CREDENTIAL_STORE=memory RTK_DISABLED=1 && \
  bash scripts/run-enterprise-e2e-live-test.sh --host cursor --resume
'
```

4. **After every SB harness fix:** `bash scripts/install-cursor.sh` then `SB_E2E_MATRIX_FORCE=1` on failed row.

**Remaining (P2):** one full row live CI fixture per host (M7); Cursor in-session matrix mode docs.

### Matrix row template (Cursor agent — test app CWD)

```
Enterprise E2E matrix row {ROW} — Cursor host track.

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
| **A — Drive** | Matrix batch | `bash scripts/run-enterprise-e2e-live-test.sh --host cursor --resume` |
| **B — Monitor** | Batch health | Full env block from [CURSOR-TUI-PROTOCOL.md](./CURSOR-TUI-PROTOCOL.md) + `bash scripts/monitor-enterprise-e2e-matrix.sh &` |
| **C — Watch** | TUI friction | Same env block + `bash scripts/watch-enterprise-e2e-tui.sh &` |

Batch PID: `kill -0 "$(cat .e2e-matrix-cursor-batch.pid)"`.

---

## Phase C — gates (outcome, validation, RCS, tri-host)

Run after matrix 22/22 evidence PASS:

```bash
cd "$SB_ROOT"
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md
export RTK_DISABLED=1

# Outcome harness:
bash tests/scripts/test-outcome-assessment.sh

# Full test suite:
bash tests/run-all-tests.sh

# Validation overlay:
bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md \
  bash scripts/run-enterprise-e2e-validation-overlay.sh --live

# Pre-release overlay + Cursor tri-host + CLI smoke:
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host cursor
CURSOR_API_KEY="$CURSOR_API_KEY" AGENT_CLI_CREDENTIAL_STORE=memory \
  bash scripts/pre-release-cursor-cli-smoke.sh

# Ledger reconcile:
bash scripts/lib/enterprise-e2e-ledger-reconcile.sh .e2e-matrix-cursor-live.log

# RCS score:
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host cursor
export SB_E2E_RCS_TRIHOST=full

# RCS score:
SB_E2E_RCS_TRIHOST=full SB_E2E_RCS_VALIDATION_OVERLAY=pass RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh
```

**Release pair:** Round Cursor-1 strict-clean + Round Cursor-2 strict-clean (consecutive) before Cursor host release sign-off.

---

## Two-round release gate (Cursor host)

**Do not tag or sign off** until **both** rounds are strict-clean **back-to-back** (Round Cursor-2 immediately follows a strict-clean Round Cursor-1 — no intervening dirty round or skipped Phase A–C).

| Step | Action |
|------|--------|
| 1 | Complete **Round Cursor-1** Phases A → B → C; set `Round clean? = Pass` in [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md). |
| 2 | Update [ROUND-CURSOR-1-GATES.md](./ROUND-CURSOR-1-GATES.md): all gates green including **2 consecutive strict clean rounds = PENDING (1/2)**. |
| 3 | **Fresh Round Cursor-2:** copy ledger template → [ROUND-CURSOR-2-LEDGER.md](./ROUND-CURSOR-2-LEDGER.md); reset matrix log (archive Cursor-1 log); re-run **full** Phase A (ladder 8/8 × 2 verify, `SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0`) + Phase B (22/22) + Phase C. |
| 4 | Pin `SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-2-LEDGER.md` for Round 2 only. |
| 5 | After Round Cursor-2 strict-clean: update [ROUND-CURSOR-2-GATES.md](./ROUND-CURSOR-2-GATES.md) — **2 consecutive strict clean rounds = PASS (2/2)**. |
| 6 | **Release readiness:** both gate files show Round N strict-clean + consecutive pair PASS; RCS ≥ 85 with `SB_E2E_RCS_TRIHOST=full`; pre-release overlay + `pre-release-cursor-cli-smoke.sh` green. |

**Failure between rounds:** If Round Cursor-2 is not strict-clean, the pair resets — fix SB, re-run Round Cursor-2 from Phase A (do not claim release until a **new** consecutive pair completes).

**Cross-round check (manual until harness script exists):**

```bash
grep -E 'Round clean\? \| \*\*Pass\*\*|2 consecutive strict clean rounds \| \*\*PASS \(2/2\)\*\*' \
  .planning/enterprise-e2e/ROUND-CURSOR-{1,2}-GATES.md
```

Harness does **not** auto-enforce the pair — operator + gate files are authoritative ([ROUND-N-GATES.md](./ROUND-N-GATES.md) row **2 consecutive strict clean rounds**).

---

## Cursor agent TUI protocol

Full checklist: [CURSOR-TUI-PROTOCOL.md](./CURSOR-TUI-PROTOCOL.md)

### Invoke patterns

| Action | Cursor agent |
|--------|----------------|
| Bootstrap | `silver-init` skill / natural-language init in test app workspace |
| Router | `/silver` or natural-language → orchestrator parent mode |
| Clarify | `silver-clarify` when ambiguous |
| Ladder | `silver-review-fix-ladder` in SB repo workspace |
| Feature/UI/etc. | Per matrix card routed skills |

### CLI headless spawn (matrix driver)

```bash
agent -p "$(cat prompt.txt)" \
  --workspace /Users/shafqat/projects/enterprise-grade-test-app \
  --api-key "$CURSOR_API_KEY" \
  --model composer-2.5
```

Adapter: `tests/live/agents/cursor/agent.sh` — `agent_preflight`, `agent_cli_path` (`cursor-agent` then `agent`).

### In-session IDE mode

When operator runs inside Cursor IDE Composer:

```bash
export SB_LIVE_CURSOR_IN_SESSION=1
export CURSOR_AGENT=1
```

File-based protocol in `${SB_LIVE_CURSOR_SESSION_DIR:-${WORK_DIR}/.cursor-live-session}`.

### Friction watch (during each row)

Read **during** each row, not only at row end:

- `.e2e-row{N}-attempt.log`, `.e2e-matrix-cursor-live.log`, monitor status, agent transcript
- Watch for: 0-token turns, MCP auth banners, orchestrator parent bash deny, stop-hook loops, `install-cursor` hangs, plugin cache mismatch, duplicate subagents (`composer-2.5-fast` violations), Keychain auth prompts in headless mode, outcome FAIL with evidence PASS
- **3 idle polls on same row → investigate**

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
- On friction: diagnose from logs → fix in SB repo → `install-cursor.sh` → `graphify update .` → `SB_E2E_MATRIX_FORCE=1` on affected row → persist new issues (0 new for strict-clean).

---

## Strict-clean criteria (Cursor track)

Same as [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §A, with Cursor-specific substitutions:

- `install-cursor.sh` instead of `install-claude.sh`
- Cursor rules/skills + `agent` CLI instead of Claude `/silver:*` slash commands
- Ledger: `ROUND-CURSOR-1-LEDGER.md` / `ROUND-CURSOR-2-LEDGER.md`
- Log: `.e2e-matrix-cursor-live.log`
- Task subagents: `composer-2.5` only

---

## Known harness gaps + operator responsibilities

| Gap | Operator action |
|-----|-----------------|
| `run-enterprise-e2e-live-test.sh` has no `--host cursor` | Wire via env + matrix runner patch; file SB issue; implement `--host` flag |
| `run-enterprise-e2e-matrix.sh` hardcodes `SILVER_BULLET_RUNTIME=claude` | Patch to honor `SB_E2E_LIVE_RUNTIME`; add CI test |
| Claude-specific expect/TUI scripts | Adapt for `agent` CLI stdout patterns |
| Claude routing state path | Add Cursor runtime state dir via `SB_RUNTIME_STATE_DIR` / `CURSOR_PLUGIN_ROOT` |
| Keychain login in headless matrix | Use `CURSOR_API_KEY` + `AGENT_CLI_CREDENTIAL_STORE=memory` per smoke script |
| In-session vs CLI mode detection | Honor `SB_LIVE_CURSOR_IN_SESSION` in matrix driver |
| Outcome re-score per row | Run `enterprise_e2e_outcome_row_passes` after each row FORCE retry |

**File issues** in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`. **Implement host wiring** in SB repo — do not workaround in test app product code.

---

## Resume commands (Cursor track)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-cursor-live.log"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SESSION0_SKIP=1   # only if Session 0 already Pass in ledger
export RTK_DISABLED=1
export CURSOR_API_KEY="${CURSOR_API_KEY:?}"
export AGENT_CLI_CREDENTIAL_STORE=memory
cd "$SB_ROOT"

# 1. Read ledger + verify driver alive:
kill -0 "$(cat .e2e-matrix-cursor-batch.pid 2>/dev/null)" 2>/dev/null || echo "driver dead"

# 2. If dead: clear stale lock, single relaunch (tmux if no PTY):
rm -f .e2e-live-test.lock
tmux new-session -d -s cursor-e2e bash -lc '
  cd "$SB_ROOT" && SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor \
    SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md \
    SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-live.log RTK_DISABLED=1 \
    CURSOR_API_KEY="$CURSOR_API_KEY" AGENT_CLI_CREDENTIAL_STORE=memory \
    bash scripts/run-enterprise-e2e-matrix.sh --resume
'

# 3. Poll (no second driver while batch alive):
tail -f .e2e-matrix-cursor-live.log
tail -f .e2e-matrix-cursor-monitor-status.txt

# 4. Preflight only:
RTK_DISABLED=1 SILVER_BULLET_RUNTIME=cursor bash tests/e2e-live/hook-delivery-preflight.sh

# 5. Cursor CLI smoke:
CURSOR_API_KEY="$CURSOR_API_KEY" AGENT_CLI_CREDENTIAL_STORE=memory \
  bash scripts/pre-release-cursor-cli-smoke.sh

# 6. Outcome harness verify:
RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh
```

---

## One-liner (fresh session copy-paste)

> Cursor enterprise E2E v2 (shared harness `scripts/enterprise-e2e/`): **2 consecutive strict-clean rounds** (Cursor-1→2). SB `/Users/shafqat/projects/silver-bullet/repo`, agent CWD `/Users/shafqat/projects/enterprise-grade-test-app`, `--host cursor` or `SB_E2E_LIVE_RUNTIME=cursor`, ledger `ROUND-CURSOR-{1,2}-LEDGER.md`, log `.e2e-matrix-cursor-live.log`. One `composer-2.5` parent orchestrator + `cursor-agent` matrix child, poll 60–90s. Each round: ladder 8/8×2 verify → matrix 22/22 → Phase C outcome+RCS+CLI smoke. Deterministic preflight: `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh`. Fix shared `enterprise-e2e/lib/` not forks; `CURSOR_API_KEY` headless; parallel Claude R6 — not smoke.
