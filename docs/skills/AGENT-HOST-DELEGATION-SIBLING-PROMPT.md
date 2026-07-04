# Agent host delegation — sibling meta-prompt

Copy-paste template for sibling host agents (Claude, Cursor, Codex, future hosts) to build their own **`/silver:agent-<host>`** on-demand delegation skills. Canonical reference implementation: **`/silver:agent-codex`** merged on `main` @ [`83e42c34`](https://github.com/alo-exp/silver-bullet/commit/83e42c34).

**Source of truth in this repo:**

| Artifact | Path |
|----------|------|
| Canonical skill (Codex) | [`skills/silver-agent-codex/SKILL.md`](../../skills/silver-agent-codex/SKILL.md) |
| Delegate wrapper (Codex) | [`scripts/agent-codex-delegate.sh`](../../scripts/agent-codex-delegate.sh) |
| Live adapter (Codex) | [`tests/live/agents/codex/agent.sh`](../../tests/live/agents/codex/agent.sh) |
| Structural test (Codex) | [`tests/scripts/test-agent-codex-skill.sh`](../../tests/scripts/test-agent-codex-skill.sh) |
| Cursor sibling (when present) | [`skills/silver-agent-cursor/SKILL.md`](../../skills/silver-agent-cursor/SKILL.md) |
| E2E adapters (matrix only) | [`scripts/enterprise-e2e/lib/adapters/`](../../scripts/enterprise-e2e/lib/adapters/) |
| Host isolation policy | [`docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md` §9](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) |

---

## Mission

Build a **per-task, on-demand subagent delegation** skill — **not** a session-persistent advisor.

| Model | Skill family | Lifetime | Parent role |
|-------|--------------|----------|-------------|
| **On-demand delegation** | `/silver:agent-<host>` | One bounded task → tear down | Brief, checkpoint, escalate, verify evidence |
| **Session advisor** | Sidekick (separate skill) | Cross-session gates, mentor memory | Quality gates across turns |
| **Enterprise E2E matrix** | Matrix harness + adapters | 22-row certification ledger | Operator protocol — **out of scope** |

The parent host **supervises**; the target host CLI **executes** in a real project `WORK_DIR`. Each invocation is independent — no delegation marker persists across sessions.

---

## Host-specific targets

Replace `<host>`, `<HOST>`, and placeholders below.

### `/silver:agent-codex` — **reference (shipped)**

| Item | Value |
|------|-------|
| Skill dir | `skills/silver-agent-codex/` |
| Route | `/silver:agent-codex` |
| Wrapper | `scripts/agent-codex-delegate.sh` |
| Live adapter | `tests/live/agents/codex/agent.sh` |
| Invoke | Codex TUI via `codex-interactive-invoke.py`; headless fallback `--use-exec` |
| Work dir env | `CODEX_WORK_DIR` |
| Route syntax in child prompts | `$silver:*` (Codex picker) |
| Planning logs | `.planning/agent-codex/` (gitignored) |

### `/silver:agent-claude` — **to build**

| Item | Placeholder |
|------|-------------|
| Skill dir | `skills/silver-agent-claude/` |
| Route | `/silver:agent-claude` |
| Wrapper | `scripts/agent-claude-delegate.sh` |
| Live adapter | Reuse [`tests/live/agents/claude/agent.sh`](../../tests/live/agents/claude/agent.sh) |
| Invoke | Claude TUI via `scripts/claude-interactive-invoke.expect` (expect); print fallback when non-interactive |
| Work dir env | `CLAUDE_WORK_DIR` |
| Route syntax in child prompts | `/silver:*` or `[$silver]` per Claude picker |
| Planning logs | `.planning/agent-claude/` (add to `.gitignore`) |
| Auth | OAuth / Keychain via `scripts/lib/claude-matrix-auth.sh` — **no** mid-delegation key rotation |
| State isolation | Fresh `${SB_RUNTIME_STATE_DIR}` per delegation wave when matrix parity needed (E2E-105) |

### `/silver:agent-cursor` — **reference (shipped or in-flight)**

| Item | Value |
|------|-------|
| Skill dir | `skills/silver-agent-cursor/` |
| Route | `/silver:agent-cursor` |
| Wrapper | `scripts/agent-cursor-delegate.sh` |
| Live adapter | [`tests/live/agents/cursor/agent.sh`](../../tests/live/agents/cursor/agent.sh) |
| Invoke | `cursor-agent` headless CLI (`SB_LIVE_CURSOR_FORCE_HEADLESS=1`); IDE in-session only for explicit bridge tests |
| Work dir env | `CURSOR_WORK_DIR` |
| Route syntax in child prompts | `/silver:*` (Cursor picker) |
| Planning logs | `.planning/agent-cursor/` (gitignored) |
| Model policy | **`composer-2.5` only** — never `composer-2.5-fast` |
| Auth | Keychain via `cursor-agent login` — **unset** `CURSOR_API_KEY` in delegate wrapper |

### Optional fourth host stub — `<HOST4>` (e.g. `opencode`, `windsurf`, `gemini-cli`)

| Item | Placeholder |
|------|-------------|
| Skill dir | `skills/silver-agent-<host4>/` |
| Route | `/silver:agent-<host4>` |
| Wrapper | `scripts/agent-<host4>-delegate.sh` |
| Live adapter | `tests/live/agents/<host4>/agent.sh` (create if missing) |
| E2E adapter | `scripts/enterprise-e2e/lib/adapters/<host4>.sh` (matrix only — do not wire into delegate) |
| Work dir env | `<HOST4>_WORK_DIR` |
| Lock file (matrix) | `.e2e-live-test-<host4>.lock` per §9 |

---

## Mandatory parity checklist (derive from agent-codex)

Complete **every** item before merging a new `/silver:agent-<host>` skill.

### 1. SKILL.md structure

- [ ] `skills/silver-agent-<host>/SKILL.md` with YAML frontmatter:
  - `name: silver-agent-<host>`
  - `description:` mentions on-demand, parent-supervised, **not** enterprise E2E matrix
  - `argument-hint:`, `user-invocable: true`, `version: 0.1.0`
- [ ] H1: `# /silver:agent-<host> — <Host> Subagent Delegation`
- [ ] **Contrast with Sidekick** — session-persistent vs per-task tear-down
- [ ] **Contrast with enterprise E2E matrix** — reuses live adapter; omits ledger / §5b product gates / fixture locks
- [ ] Sections: When to use (table) → Roles → Activation → Parent orchestrator rules → Brief → Environment → Invoke → Supervision (checkpoints + escalation ladder) → Completion criteria → Capture → When not to delegate → References
- [ ] Brief template: Task, Acceptance criteria, Constraints, Evidence required
- [ ] Document `failure_class` enum for FAIL outcomes
- [ ] Document **agentmemory** + **graphify** capture (parent before brief; parent after completion)

### 2. Router registration

- [ ] Add routing row to [`skills/silver/SKILL.md`](../../skills/silver/SKILL.md) intent table (natural-language triggers → `silver:agent-<host>`)
- [ ] Add case to [`tests/integration/test-skill-execution-paths.sh`](../../tests/integration/test-skill-execution-paths.sh) (`silver:agent-<host>` → `silver-agent-<host>`)
- [ ] Allow parent orchestrator invoke in [`hooks/lib/orchestrator-parent.sh`](../../hooks/lib/orchestrator-parent.sh):
  - `sb_orchestrator_parent_bash_allowed`: `agent-<host>-delegate.sh`
  - `sb_orchestrator_parent_skill_allowed`: `silver-agent-<host>`

### 3. Delegate wrapper (`scripts/agent-<host>-delegate.sh`)

- [ ] Executable bash; `set -euo pipefail`
- [ ] CLI: `--work-dir`, `--prompt` | `--brief-file` | `--prompt-file`, `--log`, `--mode permissive|strict`, `--sb-root`
- [ ] Resolves and **sources** `tests/live/agents/<host>/agent.sh` — **do not** duplicate invoke logic in the wrapper
- [ ] Quota retry loop (`AGENT_<HOST>_QUOTA_RETRY_INTERVAL`, `AGENT_<HOST>_QUOTA_RETRY_MAX`)
- [ ] Log redaction (api keys, tokens) before writing `--log`
- [ ] `RTK_DISABLED=1` during invoke for readable ops logs
- [ ] **Omits** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, matrix PID files

### 4. Reuse live `agent.sh` (do not fork matrix driver)

- [ ] Wrapper calls `agent_preflight` + `agent_invoke` from live adapter
- [ ] Matrix-only paths stay behind `SB_E2E_ENTERPRISE_MATRIX=1` inside adapter — delegate never sets them
- [ ] E2E thin adapter (`scripts/enterprise-e2e/lib/adapters/<host>.sh`) remains **separate** — install/preflight/row hooks only

### 5. Lightweight mode / MCP skip / orchestrator worker env

| Env | Delegate default | Purpose |
|-----|------------------|---------|
| `SB_AGENT_<HOST>_LIGHTWEIGHT` | `1` | Strip heavy boot; child executes directly |
| `SB_AGENT_<HOST>_DELEGATE` | `1` | Adapter detects delegation vs matrix |
| `SB_ORCHESTRATOR_WORKER` | `1` | Child must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | `0` | Paired with worker flag |
| Host-specific lightweight | see per-host table | e.g. Codex: ephemeral `CODEX_HOME` + MCP strip; Cursor: force headless + stream-json |

Fixture / live-test only: set `SB_AGENT_<HOST>_FIXTURE=1`, `SB_AGENT_<HOST>_LIGHTWEIGHT=0` when full MCP boot is required.

### 6. Supervision model (in SKILL.md)

- [ ] Brief → Launch → Checkpoint 1 (ack) → Checkpoint 2 (idle watch) → Complete → Mentor note
- [ ] Escalation ladder rows: **stuck**, **quota**, **auth**, **hook-trust** (if applicable), **harness**, **product** (+ host-specific: model-policy, log-floor)
- [ ] Parent must not implement delegated work in parallel on same files

### 7. Ship gates (before merge to `main`)

- [ ] **Thermo dual review** — launch `thermo-nuclear-review-subagent` on branch diff; address or waive with evidence
- [ ] **Thermo code quality** — launch `thermo-nuclear-code-quality-review-subagent` on maintainability / 1k-line rule
- [ ] **Sentinel security** — run security review on delegate wrapper + adapter changes; no secrets in committed logs
- [ ] **Real smoke test** on **isolated** `enterprise-grade-test-app` branch (or host worktree per §9):
  - Parent writes brief under `.planning/agent-<host>/smoke/`
  - Run `bash scripts/agent-<host>-delegate.sh --work-dir <fixture> --brief-file ... --log ...`
  - Verify commit SHA + acceptance criteria + log bytes (host-specific floor if any)
  - Record `result.md` with PASS/FAIL and `failure_class`
- [ ] Do **not** claim PASS on timeout-only logs or parent-routing-only with zero worker delta

### 8. Structural test

- [ ] `tests/scripts/test-agent-<host>-skill.sh` — grep-based contract mirroring [`test-agent-codex-skill.sh`](../../tests/scripts/test-agent-codex-skill.sh)
- [ ] Asserts: SKILL frontmatter, route, matrix exclusion docs, delegate references, wrapper sources live adapter, lightweight/orchestrator env, `bash -n` on wrapper
- [ ] Wire into CI if sibling tests are listed in `tests/run-all-tests.sh` or targeted pre-merge script

### 9. Sync generated surfaces

```bash
bash scripts/sync-codex-package.sh    # agents/, host-bundles/, plugins/silver-bullet/skill-source/
bash scripts/generate-plugin-commands.sh  # only if adding a new top-level composer route (agent-* skills are Skill-tool-only)
```

- [ ] `.gitignore` entry for `.planning/agent-<host>/`
- [ ] `graphify update .` after code edits

---

## Per-host variation table

| Dimension | Codex | Claude | Cursor | Fourth host |
|-----------|-------|--------|--------|-------------|
| **Invoke CLI** | `codex` (TUI / `codex exec`) | `claude` (expect TUI / print) | `cursor-agent` headless | `<cli>` |
| **Harness script** | `codex-interactive-invoke.py` | `claude-interactive-invoke.expect` | inline in `agent.sh` + stream-json | TBD |
| **Work dir env** | `CODEX_WORK_DIR` | `CLAUDE_WORK_DIR` | `CURSOR_WORK_DIR` | `<HOST>_WORK_DIR` |
| **SB_ROOT** | SB checkout with full `tests/live/` | same | same | same |
| **Child route syntax** | `$silver:*` | `/silver:*` or `[$silver]` | `/silver:*` | host picker |
| **CWD policy** | `cd "$CODEX_WORK_DIR"` in harness | `cd "$CLAUDE_WORK_DIR"` | `cd "$CURSOR_WORK_DIR"` | `cd "$WORK_DIR"` |
| **Auth** | Codex login / API in `CODEX_HOME` | OAuth; `claude-matrix-auth.sh` | Keychain `cursor-agent login`; no `CURSOR_API_KEY` | TBD |
| **Lightweight hook** | Ephemeral `CODEX_HOME`, MCP strip | Fresh runtime state dir optional | `SB_LIVE_CURSOR_FORCE_HEADLESS=1`, stream-json | TBD |
| **Headless fallback** | `--use-exec` | print mode when expect unavailable | default headless | TBD |
| **Matrix lock file** | `.e2e-live-test-codex.lock` | `.e2e-live-test.lock` | `.e2e-live-test-cursor.lock` | `.e2e-live-test-<host>.lock` |
| **Fixture branch** | `enterprise-e2e/round-N-codex` | `round6` / host branch | `enterprise-e2e/round-N-cursor` worktree | per §9 |
| **Quota env** | `AGENT_CODEX_QUOTA_RETRY_*` | `AGENT_CLAUDE_QUOTA_RETRY_*` | `AGENT_CURSOR_QUOTA_RETRY_*` | `AGENT_<HOST>_QUOTA_RETRY_*` |
| **Log evidence** | exit 0 + redacted log | expect log file | `SB_AGENT_CURSOR_LOG_FLOOR` (2048 B) | define floor |
| **Model policy** | `CODEX_MODEL` optional | `CLAUDE_MODEL` default sonnet | **`composer-2.5` mandatory** | TBD |

---

## Anti-patterns (do not copy from E2E matrix)

| Anti-pattern | Why |
|--------------|-----|
| Setting `SB_E2E_ENTERPRISE_MATRIX=1` in delegate wrapper | Turns on ledger, row writers, matrix timeouts — not single-task delegation |
| Loading `SB_E2E_LEDGER_FILE`, batch PID files, matrix quiesce | Operator certification artifacts |
| Copying §5b product gates verbatim into SKILL.md | Adapt completion criteria for production delegation; cite §5b as methodology reference only |
| Session-persisting delegation state like Sidekick | Each `/silver:agent-<host>` invocation must tear down |
| Parent implementing delegated edits in parallel | Violates orchestrator parent contract |
| `pkill` / removing another host's lock files | §9 cross-agent isolation |
| Committing `.planning/agent-<host>/*.log` | May contain secrets — gitignore only |
| Duplicating invoke logic instead of sourcing `tests/live/agents/<host>/agent.sh` | Drift from live certification harness |
| Using `composer-2.5-fast` for Cursor delegation | Global subagent policy violation |

---

## Prompt for Claude agent

```markdown
You are building `/silver:agent-claude` in the Silver Bullet repo (`/Users/shafqat/projects/silver-bullet/repo`).

**Mission:** On-demand, single-task delegation from a parent host (Cursor, Codex, or Claude parent) to **Claude TUI** as executor — parent supervises (brief → checkpoint → escalate); Claude implements in `CLAUDE_WORK_DIR`. NOT Sidekick session mode. NOT enterprise E2E matrix.

**Read first (graphify query before grep):**
- `skills/silver-agent-codex/SKILL.md` — canonical pattern
- `scripts/agent-codex-delegate.sh` — wrapper shape
- `tests/live/agents/claude/agent.sh` — reuse this adapter
- `scripts/claude-interactive-invoke.expect`
- `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` — full checklist

**Deliverables:**
1. `skills/silver-agent-claude/SKILL.md` — mirror codex structure; Claude-specific env (`CLAUDE_WORK_DIR`, expect invoke, `/silver:*` routes, OAuth auth policy)
2. `scripts/agent-claude-delegate.sh` — sources `tests/live/agents/claude/agent.sh`; lightweight defaults (`SB_ORCHESTRATOR_WORKER=1`, `RTK_DISABLED=1`, quota retry); no matrix env
3. Router: `skills/silver/SKILL.md` row, `hooks/lib/orchestrator-parent.sh` allowlist, `tests/integration/test-skill-execution-paths.sh` case
4. `tests/scripts/test-agent-claude-skill.sh` — structural contract
5. `.gitignore` → `.planning/agent-claude/`
6. `bash scripts/sync-codex-package.sh`
7. Real smoke: isolated test-app branch, brief + delegate + commit evidence → `.planning/agent-claude/smoke/result.md`

**Ship gates:** Thermo dual review + Sentinel security on diff; smoke PASS with commit SHA.

**Anti-patterns:** No `SB_E2E_ENTERPRISE_MATRIX`, no ledger, no session persistence, no parallel parent edits on delegated files.

Return: changed file list + smoke commit SHA + structural test output.
```

---

## Prompt for Cursor agent

```markdown
You are extending or verifying `/silver:agent-cursor` in the Silver Bullet repo (`/Users/shafqat/projects/silver-bullet/repo`).

**Mission:** On-demand, single-task delegation from a parent host (Claude, Codex, or Cursor parent) to **cursor-agent** headless CLI as executor — parent supervises (brief → checkpoint → escalate); Cursor implements in `CURSOR_WORK_DIR`. NOT Sidekick session mode. NOT enterprise E2E matrix.

**Read first (graphify query before grep):**
- `skills/silver-agent-codex/SKILL.md` — canonical pattern (merged @ 83e42c34)
- `skills/silver-agent-cursor/SKILL.md` — Cursor sibling (if present)
- `scripts/agent-cursor-delegate.sh`, `tests/live/agents/cursor/agent.sh`
- `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` — full checklist

**If skill missing, deliver:**
1. `skills/silver-agent-cursor/SKILL.md` — headless `cursor-agent`, Keychain auth (unset `CURSOR_API_KEY`), `composer-2.5` only, stream-json log capture, `SB_AGENT_CURSOR_LOG_FLOOR`
2. `scripts/agent-cursor-delegate.sh` — sources live adapter; `SB_LIVE_CURSOR_FORCE_HEADLESS=1`; orchestrator worker bypass
3. Router: `skills/silver/SKILL.md` row, `hooks/lib/orchestrator-parent.sh`, `tests/integration/test-skill-execution-paths.sh`
4. `tests/scripts/test-agent-cursor-skill.sh`
5. `.gitignore` → `.planning/agent-cursor/`
6. `bash scripts/sync-codex-package.sh`
7. Real smoke on isolated worktree (`enterprise-grade-test-app-cursor` per TEST-APP-BRANCH-POLICY) → `.planning/agent-cursor/smoke/result.md`

**Ship gates:** Thermo dual review + Sentinel security; smoke PASS with log ≥ 2048 B and commit SHA.

**Anti-patterns:** No matrix ledger, no IDE in-session mode in delegate default, no `composer-2.5-fast`, no `CURSOR_API_KEY` in delegate.

Return: changed file list + smoke evidence + structural test output.
```

---

## Prompt for fourth host agent (`<HOST4>`)

```markdown
You are building `/silver:agent-<HOST4>` in the Silver Bullet repo.

Follow `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` end-to-end. Use `skills/silver-agent-codex/SKILL.md` + `scripts/agent-codex-delegate.sh` as the template.

**Prerequisites:** `tests/live/agents/<HOST4>/agent.sh` must implement `agent_name`, `agent_preflight`, `agent_invoke` (see codex/claude/cursor adapters).

**Mission:** Per-task on-demand delegation only — not Sidekick, not E2E matrix.

**Deliverables:** SKILL.md, agent-<HOST4>-delegate.sh, structural test, router registration, sync-codex-package.sh, isolated smoke on dedicated fixture branch/worktree, Thermo + Sentinel reviews.

Return: file list + smoke commit SHA.
```

---

## Version history

| Date | Change |
|------|--------|
| 2026-07-04 | Initial meta-prompt; codex reference @ 83e42c34; cursor/claude stubs |
