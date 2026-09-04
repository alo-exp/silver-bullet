# Enterprise E2E Live Test — Operator Runbook

Optional live validation of Silver Bullet against the `enterprise-grade-test-app` fixture via **interactive Claude TUI**. Not run in default CI or `bash tests/run-all-tests.sh` unless explicitly opted in.

**See also:** `docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md` (staged Tier A/B/C gates — **share with Codex, Cursor, Claude agents**); `docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md` (effectiveness scoring and iteration criteria).

---

## Opt-in

```bash
cd /Users/shafqat/projects/silver-bullet/repo
export SB_ENTERPRISE_E2E_LIVE=1
bash scripts/run-enterprise-e2e-live-test.sh
```

Structural wiring only (no Claude sessions):

```bash
bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
```

Included in `run-all-tests.sh` only when `SB_ENTERPRISE_E2E_LIVE=1`.

---

## Paths

| Resource | Path |
|----------|------|
| **SB repo (fixes, release)** | `/Users/shafqat/projects/silver-bullet/repo` |
| **Test app (Claude CWD)** | `/Users/shafqat/projects/enterprise-grade-test-app` |
| **Workflow matrix** | `enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |
| **TUI protocol** | `.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md` |
| **Round 1 ledger** | `.planning/enterprise-e2e/ROUND-1-LEDGER.md` |
| **Round 2 ledger** | `.planning/enterprise-e2e/ROUND-2-LEDGER.md` |
| **Session prompt (fixture)** | `enterprise-grade-test-app/docs/ENTERPRISE-E2E-SESSION-PROMPT.md` |

---

## Auth — token gateway (NO login / NO logout)

Round 1/2 learnings:

- **Third-party API key / custom gateway** in `~/.codex/settings.json` (`ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL` — e.g. MiniMax M3 proxy).
- Matrix runner exports settings env via `claude_matrix_export_settings_env` so spawned interactive TUI matches manual sessions (`SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0` default).
- The TUI may show **"Not logged in · Please run /login"** — this is an OAuth UI state only; token gateway auth is valid. Harness ignores the banner; **never** run `/login` or `claude auth login/logout`.
- **`SB_E2E_MATRIX_CLEAN_ENV=0`** (default) — inherit caller shell auth. Do **not** use `env -i` unless debugging OAuth conflicts.
- **Never** run `claude auth login`, `claude auth logout`, `claude /logout`, or `setup-token` during live runs.
- Network errors (`ENOTFOUND`, `ConnectionRefused`) are **not** auth failures — retry with backoff; do not re-diagnose auth.

---

## Interactive TUI only — `/silver` slash prompts

- One Claude TUI session per matrix row; **CWD must stay** the test app.
- Prompts use **`/silver` and `/silver:*` slash commands** (not legacy markdown skill links).
- Row 1 is routing-only; rows 21–22 run inside parent sessions (rows 3 and 4).
- **`SB_E2E_MATRIX_DRY_RUN` must be unset** for live runs (evidence-only dry-run is for CI wiring checks, not live).

Quiet timeouts (from Round 2):

| Row class | Env | Default |
|-----------|-----|---------|
| Row 1 routing | `SB_E2E_ROW1_QUIET_TIMEOUT` | 300s |
| Rows 2–20 workflows | `SB_E2E_WORKFLOW_QUIET_TIMEOUT` | 600s |
| General | `CLAUDE_INTERACTIVE_QUIET_TIMEOUT` | 300s |

---

## Live host wrapper and model policy (pre-release)

All live host tests must be initiated through the corresponding `/silver:agent-*` wrapper
and use the fixed model mapping below:

| Host | Required wrapper | Required model |
|------|------------------|----------------|
| Codex | `/silver:agent-codex` | **GPT-5.6 Luna Low** |
| Claude | `/silver:agent-claude` | **Haiku 4.5** |
| Cursor | `/silver:agent-cursor` | **Composer 2.5** |

This Claude runbook therefore uses `/silver:agent-claude` with **Haiku 4.5** for live
Claude rows. Raw host CLI invocations or silent model substitutions do not count as live
wrapper evidence. For the current release cycle, defer Cursor live five-tool scenarios
until the separate Cursor five-tool repair session reports completion and its changes are
available in the fixture under test.

---

## Orchestrator / Cursor operator notes

### Subagent model policy

- Parent orchestrator and enterprise E2E workers: use **Composer 2.5** (`composer-2.5`) for all Task/subagent delegations.
- **Do not** use Composer 2.5 Fast (`composer-2.5-fast`) for subagent work.
- Ladder nominal model slugs in `review-fix-ladder.py` are separate (Claude TUI matrix); this policy applies to **Cursor Task subagents only**.

---

## Dual-role monitoring (drive + monitor + watch in persistent shells)

Operator model: **dual-role** — drive the matrix in one persistent shell while monitor + watch run in parallel shells.

| Shell | Role | Command |
|-------|------|---------|
| **A — Drive** | Matrix batch | `SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh --resume` |
| **B — Monitor** | Batch health, 429/network restart | `bash scripts/monitor-enterprise-e2e-matrix.sh &` |
| **C — Watch** | Turn-level TUI findings + monitor recovery | `bash scripts/watch-enterprise-e2e-tui.sh &` |

Tail artifacts:

```bash
tail -f .e2e-matrix-live.log
tail -f .e2e-matrix-monitor-status.txt
tail -f .e2e-tui-watch-findings.jsonl
```

**Monitor policies:** 429 / Token Plan → wait **60s**; network → **120–300s** random; stall → kill hung `claude` children and restart incomplete rows only.

**Watch recovery:** if monitor dies, `watch-enterprise-e2e-tui.sh` restarts it without duplicating the matrix batch.

---

## Preflight (each round)

```bash
cd /Users/shafqat/projects/silver-bullet/repo
bash scripts/run-enterprise-e2e-live-test.sh --preflight-only
# or manually:
bash tests/e2e-live/hook-delivery-preflight.sh
bash scripts/install-claude.sh

cd /Users/shafqat/projects/enterprise-grade-test-app
git status
npm test
```

The live entrypoint runs **code-intel preflight** before hook delivery when tools are opted in (`recommended_tools.*.enabled_by_user: true` in each repo's `.silver-bullet.json`):

| Tool | Checks (when opted in) |
|------|------------------------|
| **Graphify** | `graphify-out/graph.json` exists (or `graphify update . --no-cluster`); fresh `graphify query` recorded for task context |
| **agentmemory** | Server health (`/agentmemory/health`), MCP wired, `.agentmemory/` export root per `docs/AGENTMEMORY.md` |
| **RTK** | `rtk gain --help` succeeds; host PreToolUse hook wired |
| **Context Mode** | Node ≥ 22.5; ctx MCP available; `context-mode doctor` passes |

Debug escape (not for production rounds): `--skip-code-intel-preflight`.

Record test-app `git rev-parse HEAD` in the round ledger header.

### Session-start from test app

Branch-scoped session-start runs from **test app CWD** via cursor-hook-bridge / `SILVER_BULLET_SESSION_SOURCE=startup`. Confirm `~/.codex/.silver-bullet/branch` matches the active fixture branch before matrix rows.

### Recommended tools (opt in on both repos)

| Tool | Role |
|------|------|
| **Graphify** | `graphify query` before each row; `graphify update .` after SB edits |
| **agentmemory** | MCP capture; retrieve via Graphify, not raw dumps |
| **Alumnium** | Browser/visual evidence for UI rows |
| **RTK** | Shell token compression (see RTK coexistence below) |
| **Context Mode** | MCP / large-file compression |

### RTK coexistence (scoped `RTK_DISABLED`)

RTK transparently rewrites allow-listed agent shell commands via PreToolUse hooks (e.g. `git status` → `rtk git status`) to compress output. That is desirable for **agent** sessions when `recommended_tools.rtk.enabled_by_user` is true.

SB hook subprocesses are not Shell tool calls — RTK PreToolUse does not rewrite them. When the user opts in to RTK, `hooks/lib/rtk-compat.sh` does **not** export `RTK_DISABLED` in the hook bridge, so nested git/gh inside hooks can use RTK filters. Gate regexes (`completion-audit.sh`, etc.) unwrap `rtk` / `RTK_DISABLED=1` prefixes for classification.

**Harness scripts** that parse exact command output (`run-enterprise-e2e-matrix.sh`, `install-claude.sh`, live-test entrypoint) set `SB_RTK_COMPAT_MODE=verbatim` before sourcing `rtk-compat.sh`, which forces `RTK_DISABLED=1` for deterministic behavior.

Agents needing verbatim output can still prefix `RTK_DISABLED=1 git diff main...HEAD` — upstream RTK skips rewrite.

---

## Session 0 — `/silver:init`

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
claude
```

In TUI: run **`/silver:init`**, opt in Graphify + agentmemory, `graphify update .`, **do not commit** SB init artifacts.

### Session 0 gate (before matrix rows)

`run-enterprise-e2e-live-test.sh` blocks matrix launch unless Session 0 is satisfied:

- Ledger Session 0 table shows **Pass** for Graphify + agentmemory (or Enterprise preflight), **or**
- Fixture `.silver-bullet.json` has `recommended_tools.graphify.enabled_by_user` and `recommended_tools.agentmemory.enabled_by_user` both `true`.

Debug / operator waiver (log reason):

```bash
export SB_E2E_SESSION0_SKIP=1
export SB_E2E_SESSION0_SKIP_REASON="programmatic opt-in verified manually"
```

`--preflight-only` does not require Session 0 (preflight runs before the gate).

---

## Matrix rows 1–22

```bash
# Resume from last PASS/SKIP (never restart at row 1 if row 1 already passed)
SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh --resume

# Specific failed rows only
SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh 3 14
```

Per row: `graphify query "<slug> routes hooks skills orchestrator"` → paste matrix prompt card → update ledger with Pass/Fail, optional `failure_class` (`harness` | `product` | `environmental`), and refs.

Classify failures from log snippets: `bash scripts/lib/matrix-failure-class.sh .e2e-rowN-attempt.log`

**Ledger↔monitor reconciliation:** monitor emits `COMPLETE` only when `scripts/lib/enterprise-e2e-ledger-reconcile.sh` reports 22/22 Pass in `SB_E2E_LEDGER_FILE`. Log-only 22/22 without ledger agreement surfaces `LEDGER_MISMATCH` or `STALE`.

---

## Failure handling

| Symptom | Action |
|---------|--------|
| **429 / Token Plan** | Wait **60s**, retry same row (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL`) |
| **Network blip** | Wait 120–300s; monitor auto-restarts batch |
| **Provider change / bad state** | Kill claude children; **provider restart procedure**: stop batch → `install-claude.sh` → resume incomplete rows |
| **SB hook bug** | SB repo: `/silver:add` label `enterprise-test-app` → fix → commit → **`bash scripts/install-claude.sh`** → re-run **failed row only** |
| **Branch/worktree drift** | Confirm fixture branch; reset skill state; re-run session-start from test app |
| **Pause for P1 fix** | Stop batch; fix SB; deploy via `install-claude.sh`; resume with `--resume` |
| **Monitor LEDGER_MISMATCH** | Matrix log says 22/22 but ledger &lt; 22 Pass — update ledger or re-run failed rows; monitor stays alive |
| **failure_class** | Record in ledger: `harness` (expect/TUI), `product` (hook/router), `environmental` (429/network) — helper: `matrix-failure-class.sh` |

---

## Round gates (before release)

Minimum **2 consecutive clean rounds**:

1. **22/22 PASS** in ledger (graphify + agentmemory refs)
2. **`/silver:review-fix-ladder`** — 8 rungs, 2 consecutive clean verify passes each
3. **`bash tests/run-all-tests.sh`** → 0 failures
4. **`graphify update .`** in SB repo post-fixes
5. No open MUST-FIX issues
Harness (optional): `SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1 bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host <claude|codex|cursor>` enforces **2/2** strict-clean PASS from the host gate file pair.

---

## Fresh-session prompt (paste at Claude TUI start)

Use this in a **new** Claude session with **CWD = test app**:

```
Enterprise E2E live test — Silver Bullet validation on enterprise-grade-test-app.

Working directory: /Users/shafqat/projects/enterprise-grade-test-app
SB plugin: install from /Users/shafqat/projects/silver-bullet/repo via bash scripts/install-claude.sh (latest release).

Constraints:
- API key auth only — do NOT login or logout
- Use /silver and /silver:* slash commands only (interactive TUI)
- Opt in Graphify + agentmemory (enabled_by_user: true) if not already
- Run graphify update . after init when Graphify enabled

If Session 0 not done: run /silver:init now, then stop.
If resuming matrix: tell me the next row number from ROUND-1-LEDGER.md and paste that row's prompt card from docs/WORKFLOW_E2E_MATRIX.md.

Operator monitors in parallel:
- SB repo: bash scripts/monitor-enterprise-e2e-matrix.sh
- SB repo: bash scripts/watch-enterprise-e2e-tui.sh
- Matrix log: /Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-live.log

On 429/Token Plan: wait 1 minute and retry. On SB hook fix: reinstall plugin before re-running failed rows.
```

---

## Related scripts

| Script | Purpose |
|--------|---------|
| `scripts/run-enterprise-e2e-live-test.sh` | Opt-in live entrypoint (preflight + monitor + matrix) |
| `scripts/run-enterprise-e2e-matrix.sh` | Interactive matrix row runner |
| `scripts/monitor-enterprise-e2e-matrix.sh` | Batch monitor (429/network/stall) |
| `scripts/watch-enterprise-e2e-tui.sh` | Turn-level TUI watcher + monitor recovery |
| `scripts/lib/claude-matrix-auth.sh` | Export `~/.codex/settings.json` env for TUI |
| `scripts/lib/matrix-quota.sh` | 429 / Token Plan detection |
| `tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` | Structural validation (default CI-safe) |
