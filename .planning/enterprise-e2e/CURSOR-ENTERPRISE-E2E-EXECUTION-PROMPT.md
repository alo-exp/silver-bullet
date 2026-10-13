# Cursor Host — Enterprise E2E Fresh Session Execution Prompt (v2)

**Harness:** Shared host-agnostic tree — [SHARED-HARNESS.md](./SHARED-HARNESS.md) · [HOST-CONFIG.md](./HOST-CONFIG.md) · `scripts/enterprise-e2e/`

**Host identity:** **Cursor `agent` TUI** (`cursor-agent` or `agent` CLI) — rules/skills + orchestrator parent mode.

**Parallel track:** Runs **in parallel** with ongoing Claude [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — this is the **Cursor host track**, not a 5-row smoke.

**Cross-links (reference — operational behavior is inlined below; paste this prompt only for fresh sessions):**

- [SHARED-HARNESS.md](./SHARED-HARNESS.md) — deterministic vs live layers, shared `scripts/enterprise-e2e/`
- [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) — **mandatory read before row scoring** (27 criteria + WBS)
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md) — canonical live test runbook
- [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/main/docs/WORKFLOW_E2E_MATRIX.md) — 22-row prompt cards (test app)

---

## Mission

Deliver **2 consecutive strict-clean rounds** on the **Cursor host track** (Round Cursor-1, then Round Cursor-2). Strict-clean criteria are defined in **§Mission** above — adapted for Cursor `agent` TUI instead of Claude TUI.

**SB git branch (mandatory):** All harness fixes, ledgers, and operator commits live on **`enterprise-e2e/cursor`** (canonical Cursor track branch). Create or checkout at session start from `enterprise-e2e/multi-host` if the branch does not exist. Cherry-pick verified fixes to `main` per cherry-pick policy; **never** commit Cursor harness work to `enterprise-e2e/round6`, `enterprise-e2e/multi-host`, `enterprise-e2e/codex`, or Claude branches.

**Strict-clean** = ALL of:

1. **review-fix-ladder** **8/8** rungs — **one live pass per rung** @ current install version (§11 methodology); do not repeat rungs already Pass @ `SB_INSTALL_VERSION_KEY`
2. Live matrix **22/22** evidence PASS — **one pass per row** @ install version (harness skips via `matrix.sh` + `.e2e-matrix-pass-at-version.tsv`)
3. **Every row** passes `enterprise_e2e_outcome_row_passes` (no `partial`)
4. Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 (tri-host includes Cursor)

Evidence-only PASS or SKIP rows **do not** count strict-clean.

**Single-pass-at-install-version (2026-07-01):** Do not repeat matrix rows, ladder rungs, or T1 when already Pass @ `SB_INSTALL_VERSION_KEY` (`${SB_ROOT}/.e2e-cursor-install-version.txt`). Harness logs `SKIP: row N already pass @ install <ver>`. Force: `SB_E2E_MATRIX_FORCE=1` or `SB_E2E_FORCE_ROW=1`. See [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §11.

---

## Operational policies (mandatory)

- **Compaction** on context full — **not** `/clear`.
- **No `gsd` references** anywhere (docs, prompts, commits).
- **Single driver** per host; `SB_E2E_MONITOR_AUTO_RESTART=0`; poll-only while batch alive and log growing.
- **Do not kill** healthy driver **<45 min** unless confirmed stuck/dead.
- `RTK_DISABLED=1` for harness/preflight verbatim output.
- **No** `claude auth login/logout` — this track is Cursor-only.
- **429 / quota:** retry every **60s**; not auth failure.
- Re-run `bash scripts/install-cursor.sh` after every SB harness/hook fix.
- **SB branch:** `enterprise-e2e/cursor` — verify with `git branch --show-current` before **every commit** and **every TUI monitor poll / harness restart**.
- **NEVER checkout `enterprise-e2e/codex` or `enterprise-e2e/multi-host`** during Cursor track work — unintended branch switches are catastrophic (wrong ledger paths, cross-track commits, codex-only artifacts). If you land on the wrong branch, `git checkout enterprise-e2e/cursor` immediately; do not commit until verified.
- Harness **aborts** on branch mismatch when `--host cursor` (or `SB_E2E_LIVE_RUNTIME=cursor`): `enterprise_e2e_assert_host_git_branch` in `scripts/enterprise-e2e/lib/host.sh` reads `git_branch` from `hosts.json`.
- Never commit harness work to Claude Round 6, Codex, or multi-host branches.
- Recommended tools **opted-in and verified:** Graphify, agentmemory, RTK, Context Mode, Alumnium.

---

## Outcome assessment (mandatory)

**Read** [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md) **before scoring any row.**

Score **all 27 criteria** in rubric / `outcome-criteria-registry.json`, including:

- **WBS** decomposition, supervision, verification, validation (`OUT-SUPER-01` meta-supervision loop)
- Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
- Contextual workflow tailoring, verification & validation loops, quality gates, spec-to-release traceability, knowledge management (Graphify + agentmemory JIT retrieval)
- Autonomous delivery: SB drives to completion from vague prompt; `silver-clarify` when needed — assist-only = FAIL

Any mandatory outcome failure = **row FAIL** = round **not** strict-clean. Run `enterprise_e2e_outcome_row_passes` after each row; re-score after `SB_E2E_MATRIX_FORCE=1`.

---

## Deterministic preflight (mandatory before live)

Run all green before `SB_ENTERPRISE_E2E_LIVE=1` matrix launch:

| Phase | Command |
|-------|---------|
| Structural harness | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Host preflight | `bash scripts/run-enterprise-e2e-live-test.sh --host cursor --preflight-only` |
| Dry-run matrix | `SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=cursor bash scripts/run-enterprise-e2e-matrix.sh` |

---

## Fix loop (SB codebase)

On any friction:

1. **Diagnose** from logs (no guessing).
2. **Fix** in SB repo (`scripts/enterprise-e2e/lib/` — shared across hosts; not test app product code).
3. **Commit** on `enterprise-e2e/cursor`; log verified fix in [ENTERPRISE-E2E-CHERRY-PICK.md](../../docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md).
4. **Cherry-pick** verified fixes to `main` per cherry-pick policy.
5. **`graphify update .`** after substantive SB edits; `graphify query` before scoped work.
6. Re-run affected row with **`SB_E2E_MATRIX_FORCE=1`**; then `bash scripts/install-cursor.sh`.

**Baseline:** `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` — **76** unique IDs (0 new for strict-clean). Persist new issues after each fix cycle.

---

## Session workspace

| Role | Path |
|------|------|
| **Session workspace root (SB fixes, harness, ledger)** | `/Users/shafqat/projects/silver-bullet/repo` |
| **SB git branch (Cursor harness work)** | `enterprise-e2e/cursor` |
| **Test-app git branch (matrix evidence)** | `enterprise-e2e/round-1-cursor` — [TEST-APP-BRANCH-POLICY.md](./TEST-APP-BRANCH-POLICY.md) |
| **Cursor agent TUI CWD (matrix rows, Session 0)** | `/Users/shafqat/projects/enterprise-grade-test-app` (checkout host branch above) |

**Never** use the test app as SB workspace root. Operator parent sessions use SB repo root per silver-orchestrator rules.

**Test app:** Same fixture (`enterprise-grade-test-app`) is OK for all hosts — matrix rows and Session 0 run there. **SB harness commits** stay on the Cursor-named branch only; do not use the test app repo for SB harness fixes.

**Supervisor:** Cursor Composer (parent orchestrator with `Task` tool). Matrix child is `cursor-agent` CLI — Codex TUI cannot spawn `Task`.

---

## Cross-host isolation (mandatory when Claude Round 6 active)

- **Git branches:** Claude Round 6 uses `enterprise-e2e/round6` (or its Round 6 branch). Cursor uses **`enterprise-e2e/cursor`** only. **Never** commit Cursor harness work to `enterprise-e2e/round6`, `enterprise-e2e/codex`, `enterprise-e2e/multi-host`, or `main` (except via cherry-pick after verification).
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
| SB git branch (Cursor) | `enterprise-e2e/cursor` |
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

### Git branch (session start — before install)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_BRANCH=enterprise-e2e/cursor
cd "$SB_ROOT"
git fetch origin
git checkout "$SB_E2E_BRANCH" 2>/dev/null || git checkout -b "$SB_E2E_BRANCH" enterprise-e2e/multi-host
git branch --show-current   # must show enterprise-e2e/cursor — abort if on round6/codex/multi-host
```

### Install & runtime

```bash
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

- **Preferred (live matrix/ladder):** Cursor `agent` already authenticated via **macOS Keychain** / interactive login — verify with `cursor-agent status`. Do **not** set `AGENT_CLI_CREDENTIAL_STORE=memory` for tmux drivers; leave Keychain auth intact. In-session IDE vars (`CURSOR_AGENT`, `VSCODE_IPC_HOOK`) may be used when available.
- **CI / memory-store headless:** `CURSOR_API_KEY` + `AGENT_CLI_CREDENTIAL_STORE=memory` — required only for isolated runs of `pre-release-cursor-cli-smoke.sh` or CI without Keychain. Not a blocker when agent is already logged in.
- **Or** interactive login: `cursor-agent login` / `agent login`.
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

# Cursor CLI smoke (API key isolation — CI only; skip if Keychain auth verified):
# CURSOR_API_KEY="${CURSOR_API_KEY:?set CURSOR_API_KEY}" \
#   AGENT_CLI_CREDENTIAL_STORE=memory \
#   RTK_DISABLED=1 bash scripts/pre-release-cursor-cli-smoke.sh
cursor-agent status || agent status

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

Run **8 rungs** — **one live pass per rung** when not already Pass @ install version (§11 methodology). Legacy 2× verify only after install version change or explicit `SB_E2E_MATRIX_FORCE=1`.

```bash
cd "$SB_ROOT"
export SILVER_BULLET_RUNTIME=cursor
export RTK_DISABLED=1

# Resolve rung model/reasoning for Cursor:
python3 scripts/review-fix-ladder.py --host cursor

# Live ladder smoke (structural):
SILVER_BULLET_RUNTIME=cursor bash tests/live/test-live-review-fix-ladder-smoke.sh

# Full ladder (strict-clean requires live turns, not resolver-only):
# Keychain auth: omit CURSOR_API_KEY and AGENT_CLI_CREDENTIAL_STORE=memory
SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0 \
  SILVER_BULLET_RUNTIME=cursor bash tests/live/test-live-review-fix-ladder-full-ladder.sh
```

In Cursor agent TUI (SB repo CWD for ladder fixes): invoke review-fix-ladder skill per SB routing. Record each rung in `ROUND-CURSOR-1-LEDGER.md` ladder section.

**Gate:** 8/8 rungs complete, 0 new issues in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`.

---

## Phase B — 22-row matrix (Cursor host)

### Phase B status: **READY** (harness M1–M6 on `enterprise-e2e/cursor`)

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
# Keychain auth (default): omit CURSOR_API_KEY and AGENT_CLI_CREDENTIAL_STORE=memory
# CI only: export CURSOR_API_KEY=... AGENT_CLI_CREDENTIAL_STORE=memory
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
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh

tmux new-session -d -s cursor-e2e bash -lc '
  unset AGENT_CLI_CREDENTIAL_STORE 2>/dev/null || true
  export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
  cd "$SB_ROOT" && \
  export SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor \
    RTK_DISABLED=1 && \
  bash scripts/run-enterprise-e2e-live-test.sh --host cursor --resume
'
```

4. **After every SB harness fix:** follow [Fix loop](#fix-loop-sb-codebase) — `install-cursor.sh` + `SB_E2E_MATRIX_FORCE=1` on failed row.

5. Cherry-pick verified fixes to `main` per [ENTERPRISE-E2E-CHERRY-PICK.md](../../docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md).

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

# Pre-release overlay + Cursor tri-host + CLI smoke (Keychain OK; smoke optional if status green):
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host cursor
cursor-agent status || agent status
# CI only: CURSOR_API_KEY=... AGENT_CLI_CREDENTIAL_STORE=memory bash scripts/pre-release-cursor-cli-smoke.sh

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
| 3 | **Fresh Round Cursor-2:** copy ledger template → [ROUND-CURSOR-2-LEDGER.md](./ROUND-CURSOR-2-LEDGER.md); reset matrix log (archive Cursor-1 log); re-run Phase A + Phase B + Phase C — **skip rows/rungs already Pass @ install version** (§11) |
| 4 | Pin `SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-2-LEDGER.md` for Round 2 only. |
| 5 | After Round Cursor-2 strict-clean: update [ROUND-CURSOR-2-GATES.md](./ROUND-CURSOR-2-GATES.md) — **2 consecutive strict clean rounds = PASS (2/2)**. |
| 6 | **Release readiness:** both gate files show Round N strict-clean + consecutive pair PASS; RCS ≥ 85 with `SB_E2E_RCS_TRIHOST=full`; pre-release overlay + `pre-release-cursor-cli-smoke.sh` green. |

**Failure between rounds:** If Round Cursor-2 is not strict-clean, the pair resets — fix SB, re-run Round Cursor-2 from Phase A (do not claim release until a **new** consecutive pair completes).

**Cross-round check:**

```bash
RTK_DISABLED=1 bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host cursor
# Or on live-test exit: SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1
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
# Keychain auth (default): omit --api-key
agent -p "$(cat prompt.txt)" \
  --workspace /Users/shafqat/projects/enterprise-grade-test-app \
  --model composer-2.5

# CI/memory-store only:
# agent -p "$(cat prompt.txt)" --workspace ... --api-key "$CURSOR_API_KEY" --model composer-2.5
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

## Strict-clean criteria (Cursor track)

Same as **§Mission** above, with Cursor-specific substitutions:

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
| Keychain login in headless matrix | **Valid** — default for live drivers; unset `AGENT_CLI_CREDENTIAL_STORE=memory`. Use `CURSOR_API_KEY` only for CI/memory-store smoke |
| In-session vs CLI mode detection | Honor `SB_LIVE_CURSOR_IN_SESSION` in matrix driver |
| Outcome re-score per row | Run `enterprise_e2e_outcome_row_passes` after each row FORCE retry |

**File issues** in `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`. **Implement host wiring** in SB repo — do not workaround in test app product code.

---

## Resume first actions (§H)

0. **Verify SB branch:** `cd "$SB_ROOT" && git checkout enterprise-e2e/cursor`; `git branch --show-current` must show `enterprise-e2e/cursor` — never resume harness work on `enterprise-e2e/round6`, `enterprise-e2e/codex`, or `enterprise-e2e/multi-host`.
1. **Read** current round ledger ([ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md) or Round 2); note active row and last checkpoint.
2. **Verify driver:** `kill -0 "$(cat .e2e-matrix-cursor-batch.pid 2>/dev/null)" 2>/dev/null || echo "driver dead"`.
3. **If dead:** clear **host lock only** — `rm -f .e2e-live-test-cursor.lock` (never `.e2e-live-test.lock` while Claude R6 may be live); single `--resume` relaunch (tmux if no PTY).
4. **If alive:** poll + friction watch only — **no second driver**.
5. **Post first substantive checkpoint within 90s** of session start.
6. Continue until round strict-clean + Phase C; then `bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host cursor`.

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_BRANCH=enterprise-e2e/cursor
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-cursor-live.log"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SESSION0_SKIP=1   # only if Session 0 already Pass in ledger
export RTK_DISABLED=1
# Keychain auth (default): omit CURSOR_API_KEY / AGENT_CLI_CREDENTIAL_STORE=memory
cd "$SB_ROOT"
git fetch origin && git checkout "$SB_E2E_BRANCH" || git checkout -b "$SB_E2E_BRANCH" enterprise-e2e/multi-host
git branch --show-current   # must show enterprise-e2e/cursor

# If dead — host lock only, single relaunch (Keychain auth):
rm -f .e2e-live-test-cursor.lock
tmux new-session -d -s cursor-e2e bash -lc '
  unset AGENT_CLI_CREDENTIAL_STORE 2>/dev/null || true
  export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
  cd "$SB_ROOT" && SB_ENTERPRISE_E2E_LIVE=1 SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor \
    SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md \
    SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-live.log RTK_DISABLED=1 \
    bash scripts/run-enterprise-e2e-matrix.sh --resume
'

# Poll (no second driver while batch alive):
tail -f .e2e-matrix-cursor-live.log
tail -f .e2e-matrix-cursor-monitor-status.txt
```

---

## One-liner (fresh session copy-paste)

> **Self-contained Cursor operator prompt** — paste only this file for fresh sessions (no separate addendum). SB `/Users/shafqat/projects/silver-bullet/repo` on branch **`enterprise-e2e/cursor`** (never `round6`/Codex/multi-host), agent CWD `/Users/shafqat/projects/enterprise-grade-test-app`, `--host cursor`, **2 consecutive strict-clean rounds** (Cursor-1→2). One `composer-2.5` parent + `cursor-agent` matrix child, poll 60–90s, checkpoint within 90s on resume. Read OUTCOME-ASSESSMENT-RUBRIC before row scoring (27 + WBS). Deterministic preflight: structural suite + outcome harness + `--preflight-only` + dry-run matrix (see §Deterministic preflight). Fix loop: diagnose→commit on cursor branch→cherry-pick to main→graphify→FORCE; baseline 76 issues. Host lock `.e2e-live-test-cursor.lock` only. Consecutive rounds: `enterprise-e2e-consecutive-rounds-check.sh --host cursor`. Keychain auth OK for live drivers (no `CURSOR_API_KEY` required). Compaction not `/clear`; no `gsd`.
