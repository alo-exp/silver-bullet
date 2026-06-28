# Enterprise E2E Operator Prompt — Canonical (adjacent to live test script)

Merged from:

- `/Users/shafqat/.cursor/plans/enterprise_e2e_iteration_30417faf.plan.md`
- `/Users/shafqat/projects/enterprise-grade-test-app/docs/ENTERPRISE-E2E-SESSION-PROMPT.md`
- `/Users/shafqat/projects/silver-bullet/repo/docs/ENTERPRISE-E2E-LIVE-TEST.md`

**Live test entrypoint:** `scripts/run-enterprise-e2e-live-test.sh` (this directory).

---

## Enterprise E2E Iteration — Fresh Session Prompt

Enterprise E2E live test — Silver Bullet validation on `enterprise-grade-test-app`.

**Working directory (Claude TUI CWD):** `/Users/shafqat/projects/enterprise-grade-test-app`

**SB plugin:** install from `/Users/shafqat/projects/silver-bullet/repo` via `bash scripts/install-claude.sh` (pin release commit per round ledger).

### Pinned paths

| Resource | Path |
|----------|------|
| Test app (Claude CWD) | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Silver Bullet repo | `/Users/shafqat/projects/silver-bullet/repo` |
| Iteration plan | `/Users/shafqat/.cursor/plans/enterprise_e2e_iteration_30417faf.plan.md` |
| Claude TUI protocol | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md` |
| Workflow matrix | `/Users/shafqat/projects/enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |
| Round ledgers | `/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-N-LEDGER.md` |
| Matrix live log | `/Users/shafqat/projects/silver-bullet/repo/.e2e-matrix-live.log` |
| Fixture session prompt | `/Users/shafqat/projects/enterprise-grade-test-app/docs/ENTERPRISE-E2E-SESSION-PROMPT.md` |

### Hard constraints

- **API key auth only** — do **not** run `claude auth login`, `claude auth logout`, `claude /logout`, or `setup-token` during live runs.
- **Interactive TUI only** — use `/silver` and `/silver:*` slash commands (not legacy markdown skill links).
- **Orchestrator parent** must not implement product code inline unless the workflow requires it.
- **SB fixes** in SB repo only; **product code** in test app only.
- **Do not commit** SB init artifacts from the test app to GitHub.
- **OpenCode / local proxy 429** — if `~/.claude/settings.json` sets `ANTHROPIC_BASE_URL` (e.g. `127.0.0.1:15721`), matrix defaults to `SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1` (direct OAuth). Set `=0` only for api_key-only hosts.
- **429 / Token Plan** — wait **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`) and retry the **same row**; not an auth failure.
- **Network blips** — retry with backoff (120–300s); not auth failures.
- **Harness parsing:** `RTK_DISABLED=1` / `SB_RTK_COMPAT_MODE=verbatim` on `run-enterprise-e2e-live-test.sh`, matrix runner, `install-claude.sh`.
- **graphify update** in SB repo before substantive SB edits; `graphify update .` in test app after Session 0 when Graphify is enabled.

### Mandatory recommended tools (opt in on both repos)

| Tool | Role |
|------|------|
| **Graphify** | `graphify query` before each session/row; `graphify update .` after code edits |
| **agentmemory** | Save session evidence via MCP; **retrieve via Graphify**, not raw dumps |
| **Alumnium** | Browser/visual MCP for UI workflows |
| **RTK** | Shell token compression (agent sessions) |
| **Context Mode** | MCP / large-file compression |

Set `recommended_tools.<tool>.enabled_by_user: true` in each repo's `.silver-bullet.json`.

### Execution order (each round)

1. **graphify update .** in SB repo (enterprise E2E scope).
2. **Preflight:** `bash scripts/run-enterprise-e2e-live-test.sh --preflight-only` (or hook-delivery + install-claude + test-app `npm test`).
3. **Review-fix-ladder** — 8 rungs, **2 consecutive clean verify passes** each (`/silver:review-fix-ladder` in SB repo).
4. **Full test suite:** `bash tests/run-all-tests.sh` → 0 failures.
5. **install-claude.sh** after every SB fix commit before re-running failed matrix rows.
6. **Session 0** — `/silver:init` in test app TUI; opt in tools; `graphify update .` in test app; stop after init.
7. **Matrix rows 1–22** — one TUI session per row (rows 21–22 inside parent rows 3 and 4).
8. **Dual-role monitoring** — drive matrix in shell A; `monitor-enterprise-e2e-matrix.sh` + `watch-enterprise-e2e-tui.sh` in parallel.
9. Update round ledger with Pass/Fail, `failure_class` (on Fail: `harness` | `product` | `environmental`), `graphify_query_ref`, `agentmemory_export_ref`.
10. On SB hook bug: `/silver:add` label `enterprise-test-app` → fix → commit → `install-claude.sh` → re-run **failed row only**.

### Failure classification (`failure_class`)

When a row fails, record `failure_class` in the ledger matrix table:

| Class | When to use | Examples |
|-------|-------------|----------|
| `environmental` | External quota, network, proxy — **retry same row every 60s** | API 429, Token Plan, OpenCode proxy weekly messaging (not auth); do not wait for reset without operator waiver; `ENOTFOUND` |
| `harness` | Expect/TUI/ANSI/monitor wiring | Bypass Permissions menu, `claude-interactive-invoke` |
| `product` | SB hook, router, orchestrator, evidence | Missing artifact, wrong route, hook BLOCK |

Helper: `bash scripts/lib/matrix-failure-class.sh .e2e-row{N}-attempt.log`

**Monitor rule:** `COMPLETE` requires ledger 22/22 Pass with refs — log-only 22/22 is `LEDGER_MISMATCH` (see `scripts/lib/enterprise-e2e-ledger-reconcile.sh`).

### Session 0 gate

Matrix launch requires Session 0 unless waived:

- Ledger Session 0 **Pass** for Graphify + agentmemory (or Enterprise preflight), **or**
- Fixture `.silver-bullet.json` has graphify + agentmemory `enabled_by_user: true`.

Waiver (document reason): `SB_E2E_SESSION0_SKIP=1` + `SB_E2E_SESSION0_SKIP_REASON=...`

### Clean round definition

A round is **clean** only when:

1. **Ladder:** all 8 rungs complete with **2 consecutive clean verify passes** each.
2. **Tests:** `bash tests/run-all-tests.sh` → 0 failures.
3. **Matrix:** **22/22 Pass** in ledger with graphify + agentmemory refs.
4. **graphify update .** in SB repo post-fixes.
5. **No open MUST-FIX** issues from the round.

**Release gate:** minimum **2 consecutive clean rounds** before release tag (`enterprise-e2e-matrix`, `claude-supervised` markers).

### Fresh-session copy-paste (Claude TUI — test app CWD)

```
Enterprise E2E live test — Silver Bullet validation on enterprise-grade-test-app.

Working directory: /Users/shafqat/projects/enterprise-grade-test-app
SB plugin: install from /Users/shafqat/projects/silver-bullet/repo via bash scripts/install-claude.sh (pin SHA in ROUND-N-LEDGER.md).

Constraints:
- API key auth only — do NOT login or logout
- Use /silver and /silver:* slash commands only (interactive TUI)
- Opt in Graphify + agentmemory + RTK + context_mode (enabled_by_user: true) if not already
- Run graphify update . after init when Graphify enabled
- Do not copy SB dogfood config from the plugin repo

If Session 0 not done: run /silver:init now, then stop.
If resuming matrix: read next row from ROUND-N-LEDGER.md and prompt card from docs/WORKFLOW_E2E_MATRIX.md.

Operator monitors in parallel (SB repo):
- bash scripts/monitor-enterprise-e2e-matrix.sh
- bash scripts/watch-enterprise-e2e-tui.sh
- tail -f .e2e-matrix-live.log

On 429/Token Plan: wait 1 minute (SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60) and retry same row.
On SB hook fix: reinstall plugin before re-running failed rows.
```

### Matrix row template (sessions 1–22)

```
Enterprise E2E matrix row {ROW}.

Use the Silver Bullet orchestrator — do not implement product changes inline in the parent session unless the workflow requires it.

User request (natural language):
{PROMPT_CARD}

Follow the routed workflow to completion. Record progress in .planning/workflows/ per SB conventions.
When done, summarize: route invoked, skills recorded, artifacts created, test status.
```

---

## Operator autonomy policy

### Subagent model policy

- Parent orchestrator and enterprise E2E workers: use **Composer 2.5** (`composer-2.5`) for all Task/subagent delegations.
- **Do not** use Composer 2.5 Fast (`composer-2.5-fast`) for subagent work.
- Ladder nominal model slugs in `review-fix-ladder.py` are separate (Claude TUI matrix); this policy applies to **Cursor Task subagents only**.

- **Pls do that yourself. Never pause for operator.**
- Automate Session 0 prep when possible: set `recommended_tools.graphify|agentmemory|rtk|context_mode.enabled_by_user` to `true` in `/Users/shafqat/projects/enterprise-grade-test-app/.silver-bullet.json` programmatically if TUI is unavailable; then `graphify update . --no-cluster` in the test app.
- On **Claude API 429 / quota / Token Plan**: retry every **1 minute** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`); **do not** treat as auth failure; **never** `claude auth login/logout`.
- **Do not block** on Session 0 if fixture already has partial init — complete tool opt-in and graphify update, then continue the matrix.
- Continue through the matrix without waiting for a human unless truly blocked (interactive auth login required, missing secrets, etc.).
- Use `--resume` when `.e2e-matrix-live.log` shows partial progress; never restart at row 1 if row 1 already passed.

---

## Related documentation

- Effectiveness plan: `docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`
- Runbook: `docs/ENTERPRISE-E2E-LIVE-TEST.md`
- Fixture operator copy-paste: `enterprise-grade-test-app/docs/ENTERPRISE-E2E-SESSION-PROMPT.md`
