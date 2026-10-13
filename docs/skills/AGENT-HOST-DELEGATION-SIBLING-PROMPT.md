# Agent host delegation — sibling meta-prompt

Copy-paste template for sibling host agents (Claude, Cursor, Codex, future hosts) to build their own **`/sb:agent-<host>`** on-demand delegation skills.

**Canonical reference implementations:**

| Host | Merged on `main` | Skill |
|------|------------------|-------|
| Codex | [`83e42c34`](https://github.com/alo-exp/silver-bullet/commit/83e42c34) | [`skills/silver-agent-codex/SKILL.md`](../../skills/silver-agent-codex/SKILL.md) |
| Cursor | [`7a901af4`](https://github.com/alo-exp/silver-bullet/commit/7a901af4) (feature branch) | [`skills/silver-agent-cursor/SKILL.md`](../../skills/silver-agent-cursor/SKILL.md) |

**Pilot evidence:** [`.planning/silver-agent-cursor-pilot.md`](../../.planning/silver-agent-cursor-pilot.md)

**Source of truth in this repo:**

| Artifact | Path |
|----------|------|
| Canonical skill (Codex) | [`skills/silver-agent-codex/SKILL.md`](../../skills/silver-agent-codex/SKILL.md) |
| Delegate wrapper (Codex) | [`scripts/agent-codex-delegate.sh`](../../scripts/agent-codex-delegate.sh) |
| Live adapter (Codex) | [`tests/live/agents/codex/agent.sh`](../../tests/live/agents/codex/agent.sh) |
| Structural test (Codex) | [`tests/scripts/test-agent-codex-skill.sh`](../../tests/scripts/test-agent-codex-skill.sh) |
| Canonical skill (Cursor) | [`skills/silver-agent-cursor/SKILL.md`](../../skills/silver-agent-cursor/SKILL.md) |
| Delegate wrapper (Cursor) | [`scripts/agent-cursor-delegate.sh`](../../scripts/agent-cursor-delegate.sh) |
| Live adapter (Cursor) | [`tests/live/agents/cursor/agent.sh`](../../tests/live/agents/cursor/agent.sh) |
| Structural test (Cursor) | [`tests/scripts/test-agent-cursor-skill.sh`](../../tests/scripts/test-agent-cursor-skill.sh) |
| E2E adapters (matrix only) | [`scripts/enterprise-e2e/lib/adapters/`](../../scripts/enterprise-e2e/lib/adapters/) |
| Host isolation policy | [`docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md` §9](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) |
| Shared lib (follow-up) | `scripts/lib/agent-delegate-common.sh` — **gap:** extract quota retry, redaction, log header from cursor/codex wrappers |

---

## Mission

Build a **per-task, on-demand subagent delegation** skill — **not** a session-persistent advisor.

| Model | Skill family | Lifetime | Parent role |
|-------|--------------|----------|-------------|
| **On-demand delegation** | `/sb:agent-<host>` | One bounded task → tear down | Brief, checkpoint, escalate, verify evidence |
| **Session advisor** | Sidekick (separate skill) | Cross-session gates, mentor memory | Quality gates across turns |
| **Enterprise E2E matrix** | Matrix harness + adapters | 22-row certification ledger | Operator protocol — **out of scope** |

The parent host **supervises**; the target host CLI **executes** in a real project `WORK_DIR`. Each invocation is independent — no delegation marker persists across sessions.

### Sidekick supervision borrow (without persistence)

Borrow Sidekick's **advisor–mentor** lifecycle for a **single task**:

| Phase | Parent | Persisted? |
|-------|--------|------------|
| Brief | Task + acceptance criteria + constraints | Optional `.planning/agent-<host>/<task-id>/brief.md` |
| Launch | Run `agent-<host>-delegate.sh`; tail log | Log only (gitignored) |
| Checkpoint 1 | Worker acknowledged prompt (log growth / submit marker) | — |
| Checkpoint 2 | Idle >5 min without log growth → prepare escalation | — |
| Complete | Verify acceptance criteria vs git/test/commit | `result.md` or agentmemory |
| Mentor note | Short retrospective for next delegation | agentmemory only |

Do **not** write session markers to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` or quality-gate-state.

### Original user intent (carry forward)

1. **Stand-alone per-task skill** — not session-persistent like Sidekick.
2. **Drive host TUI as subagent from any host-agent** — Claude parent → Cursor worker, Cursor parent → Codex worker, etc.
3. **Arbitrary real work** — not the E2E matrix row catalog.
4. **Review ladder before ship** — thermo-nuclear code-quality + thermo-nuclear review + security-review + Sentinel re-audit on SB-repo harness changes.
5. **Real-life pilot** — isolated test-app branch/worktree with committed product delta.
6. **Name pattern** — `/sb:agent-<host>` everywhere (router, skill frontmatter, delegate script comments).

---

## Host-specific targets

Replace `<host>`, `<HOST>`, and placeholders below.

### `/sb:agent-codex` — **reference (shipped)**

| Item | Value |
|------|-------|
| Skill dir | `skills/silver-agent-codex/` |
| Route | `/sb:agent-codex` |
| Wrapper | `scripts/agent-codex-delegate.sh` |
| Live adapter | `tests/live/agents/codex/agent.sh` |
| Invoke | Codex TUI via `codex-interactive-invoke.py`; headless fallback `--use-exec` |
| Work dir env | `CODEX_WORK_DIR` |
| Route syntax in child prompts | `$sb:*` (Codex picker) |
| Planning logs | `.planning/agent-codex/` (gitignored) |

### `/sb:agent-claude` — **to build**

| Item | Placeholder |
|------|-------------|
| Skill dir | `skills/silver-agent-claude/` |
| Route | `/sb:agent-claude` |
| Wrapper | `scripts/agent-claude-delegate.sh` |
| Live adapter | Reuse [`tests/live/agents/claude/agent.sh`](../../tests/live/agents/claude/agent.sh) |
| Invoke | Claude TUI via `scripts/claude-interactive-invoke.expect` (expect); print fallback when non-interactive |
| Work dir env | `CLAUDE_WORK_DIR` |
| Route syntax in child prompts | `/sb:*` or `[$silver]` per Claude picker |
| Planning logs | `.planning/agent-claude/` (add to `.gitignore`) |
| Auth | OAuth / Keychain via `scripts/lib/claude-matrix-auth.sh` — **no** mid-delegation key rotation |
| State isolation | Fresh `${SB_RUNTIME_STATE_DIR}` per delegation wave when matrix parity needed (E2E-105) |

### `/sb:agent-cursor` — **reference (shipped)**

| Item | Value |
|------|-------|
| Skill dir | `skills/silver-agent-cursor/` |
| Route | `/sb:agent-cursor` |
| Wrapper | `scripts/agent-cursor-delegate.sh` |
| Live adapter | [`tests/live/agents/cursor/agent.sh`](../../tests/live/agents/cursor/agent.sh) |
| Invoke | `cursor-agent` headless CLI (`SB_LIVE_CURSOR_FORCE_HEADLESS=1`); IDE in-session only for explicit bridge tests |
| Work dir env | `CURSOR_WORK_DIR` |
| Route syntax in child prompts | `/sb:*` (Cursor picker) |
| Planning logs | `.planning/agent-cursor/` (gitignored) |
| Model policy | **`composer-2.5` only** — never `composer-2.5-fast` |
| Auth | Keychain via `cursor-agent login` — **unset** `CURSOR_API_KEY` in delegate wrapper |
| Log capture | `SB_AGENT_CURSOR_STREAM_JSON=1`; log floor `SB_AGENT_CURSOR_LOG_FLOOR` (2048 B default) |
| Path policy | **Absolute paths** for `--log` and `--brief-file` (relative paths resolve under `WORK_DIR`) |

### Optional fourth host stub — `<HOST4>` (e.g. `opencode`, `windsurf`, `gemini-cli`)

| Item | Placeholder |
|------|-------------|
| Skill dir | `skills/silver-agent-<host4>/` |
| Route | `/sb:agent-<host4>` |
| Wrapper | `scripts/agent-<host4>-delegate.sh` |
| Live adapter | `tests/live/agents/<host4>/agent.sh` (create if missing) |
| E2E adapter | `scripts/enterprise-e2e/lib/adapters/<host4>.sh` (matrix only — do not wire into delegate) |
| Work dir env | `<HOST4>_WORK_DIR` |
| Lock file (matrix) | `.e2e-live-test-<host4>.lock` per §9 |

---

## Prerequisites

Before authoring a new `silver-agent-<host>` sibling:

| Prerequisite | Check |
|--------------|-------|
| Live adapter exists | `tests/live/agents/<host>/agent.sh` with `agent_preflight` + `agent_invoke` |
| Host CLI on PATH | `cursor-agent`, native Codex CLI, etc. |
| Router entry | [`skills/silver/SKILL.md`](../../skills/silver/SKILL.md) intent table row for `sb:agent-<host>` |
| Orchestrator allowlist | [`hooks/lib/orchestrator-parent.sh`](../../hooks/lib/orchestrator-parent.sh) → `sb_orchestrator_parent_skill_allowed` includes `silver-agent-<host>` |
| Parent Bash bridge | Same file → `sb_orchestrator_parent_bash_allowed` allows `agent-<host>-delegate.sh` |
| Integration alias | [`tests/integration/test-skill-execution-paths.sh`](../../tests/integration/test-skill-execution-paths.sh) `resolve_silver_alias` case |
| Logs gitignored | `.gitignore` → `.planning/agent-<host>/` |
| Methodology literacy | [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a/§5b/§8 — adapt for production delegation, do not copy matrix row gates verbatim |
| Host readiness audit | Pattern: [CURSOR-METHODOLOGY-HARNESS-READINESS-AUDIT.md](../testing/CURSOR-METHODOLOGY-HARNESS-READINESS-AUDIT.md), [CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md](../testing/CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md) |

**Composer 2.5 policy (Cursor only, mandatory):** Subagent/delegation work uses **`composer-2.5` only**. Never `composer-2.5-fast`. Enforce in delegate wrapper (`CURSOR_AGENT_MODEL`, reject `*fast*`), skill doc, and parent brief.

---

## Skill anatomy

### Frontmatter template

```yaml
---
name: silver-agent-<host>
description: On-demand parent-supervised delegation of a single real task to <Host> TUI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent should supervise while <Host> executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---
```

### Required sections (in order)

1. **Title** — `# /sb:agent-<host> — <Host> Subagent Delegation`
2. **Contrast with Sidekick** — per-task vs session-persistent
3. **Contrast with E2E matrix** — reuses live adapter; excludes matrix env/ledger
4. **When to use** — table: delegate vs inline/Task/orchestrator queue
5. **Roles** — parent supervisor vs worker executor
6. **Activation** — on-demand 4-step lifecycle
7. **Parent orchestrator rules** — parent may invoke skill + delegate.sh; must not edit delegated product
8. **Step 1 — Brief** — markdown template + graphify + agentmemory
9. **Step 2 — Environment** — fixture vs real project table + harness env + auth policy
10. **Step 3 — Invoke** — `agent-<host>-delegate.sh` examples (**absolute paths** for `--log` / `--brief-file`)
11. **Step 4 — Supervision** — checkpoints + failure escalation ladder with `failure_class` values
12. **Step 5 — Completion criteria** — §5b-adapted PASS gates (see [Pilot §5b gates](#5b-gates-adapted-for-production-delegation-pass-checklist))
13. **Step 6 — Capture** — agentmemory + graphify
14. **When parent should not delegate**
15. **References** — harness, adapter, methodology audits; matrix paths marked "matrix only"

### Brief template (parent issues before invoke)

```markdown
## Task
<one paragraph — what the worker must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): <host picker syntax>

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

### Auth model per host

| Host | Auth | Forbidden / pitfalls |
|------|------|----------------------|
| **Cursor** | Keychain via `cursor-agent login`; preflight `agent_preflight` | **Do not** set `CURSOR_API_KEY` — bypasses Keychain, breaks cert parity (methodology §8) |
| **Codex** | Native CLI session + hook trust | Use `CODEX_AUTO_TRUST_HOOKS=1`, `CODEX_BYPASS_HOOK_TRUST=1` in lightweight delegate; seed via `bash scripts/install-codex.sh --hook-trust-seed-only` on trust failure |
| **Claude** (future) | API key / OAuth per Claude Code docs | Isolate state per delegation wave; no matrix inherit-keys shortcuts (E2E-110) |
| **Gemini** (future) | TBD when adapter lands | Document in skill before ship |

### Matrix env exclusion (all hosts)

Delegate wrapper **must** `unset` inherited matrix env:

- `SB_E2E_ENTERPRISE_MATRIX`
- `SB_E2E_LEDGER_FILE`
- `SB_E2E_MATRIX_BATCH_PID`

Never load matrix ledger, row outcome writers, or fixture branch locks for normal delegation.

---

## Mandatory parity checklist (derive from agent-codex)

Complete **every** item before merging a new `/sb:agent-<host>` skill.

### 1. SKILL.md structure

- [ ] `skills/silver-agent-<host>/SKILL.md` with YAML frontmatter:
  - `name: silver-agent-<host>`
  - `description:` mentions on-demand, parent-supervised, **not** enterprise E2E matrix
  - `argument-hint:`, `user-invocable: true`, `version: 0.1.0`
- [ ] H1: `# /sb:agent-<host> — <Host> Subagent Delegation`
- [ ] **Contrast with Sidekick** — session-persistent vs per-task tear-down
- [ ] **Contrast with enterprise E2E matrix** — reuses live adapter; omits ledger / §5b product gates / fixture locks
- [ ] Sections: When to use (table) → Roles → Activation → Parent orchestrator rules → Brief → Environment → Invoke → Supervision (checkpoints + escalation ladder) → Completion criteria → Capture → When not to delegate → References
- [ ] Brief template: Task, Acceptance criteria, Constraints, Evidence required
- [ ] Document `failure_class` enum for FAIL outcomes: `stuck` | `quota` | `auth` | `model-policy` | `hook-trust` | `harness` | `product` | `log-floor`
- [ ] Document **agentmemory** + **graphify** capture (parent before brief; parent after completion)

### 2. Router registration

- [ ] Add routing row to [`skills/silver/SKILL.md`](../../skills/silver/SKILL.md) intent table (natural-language triggers → `sb:agent-<host>`)
- [ ] Add case to [`tests/integration/test-skill-execution-paths.sh`](../../tests/integration/test-skill-execution-paths.sh) (`sb:agent-<host>` → `silver-agent-<host>`)
- [ ] Allow parent orchestrator invoke in [`hooks/lib/orchestrator-parent.sh`](../../hooks/lib/orchestrator-parent.sh):
  - `sb_orchestrator_parent_bash_allowed`: `agent-<host>-delegate.sh`
  - `sb_orchestrator_parent_skill_allowed`: `silver-agent-<host>`

### 3. Delegate wrapper (`scripts/agent-<host>-delegate.sh`)

- [ ] Executable bash; `set -euo pipefail`
- [ ] CLI: `--work-dir`, `--prompt` | `--brief-file` | `--prompt-file`, `--log`, `--mode permissive|strict`, `--sb-root`
- [ ] Resolves and **sources** `tests/live/agents/<host>/agent.sh` — **do not** duplicate invoke logic in the wrapper
- [ ] **Absolute paths** for `--log` and `--brief-file` — canonicalize in wrapper (pilot lesson: relative paths resolve under `WORK_DIR`)
- [ ] Quota retry loop (`AGENT_<HOST>_QUOTA_RETRY_INTERVAL`, `AGENT_<HOST>_QUOTA_RETRY_MAX`)
- [ ] Log redaction (api keys, tokens) before writing `--log`
- [ ] `RTK_DISABLED=1` during invoke for readable ops logs
- [ ] **Omits** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, matrix PID files
- [ ] Prefer `scripts/lib/agent-delegate-common.sh` once extracted (shared quota/redaction/header — **open gap**)

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

**Cursor-specific** (`agent-cursor-delegate.sh`):

| Env | Default | Purpose |
|-----|---------|---------|
| `CURSOR_AGENT_TIMEOUT` | 1800 | Hard timeout (E2E-087/092) |
| `CURSOR_AGENT_MODEL` / `CURSOR_MODEL` | `composer-2.5` | Model policy |
| `SB_AGENT_CURSOR_STREAM_JSON` | 1 | stream-json capture (E2E-093) |
| `SB_AGENT_CURSOR_LOG_FLOOR` | 2048 | Minimum log bytes for PASS |
| `SB_LIVE_CURSOR_FORCE_HEADLESS` | 1 | `cursor-agent` CLI, not IDE session |

**Codex-specific** (`agent-codex-delegate.sh`):

| Env | Default | Purpose |
|-----|---------|---------|
| `CODEX_INTERACTIVE_READY_TIMEOUT` | 120 via delegate | Model/MCP boot |
| `CODEX_INTERACTIVE_IDLE_TIMEOUT` | 3600 via delegate | Idle watchdog |
| `SB_AGENT_CODEX_LIGHTWEIGHT` | 1 | Ephemeral `CODEX_HOME`, MCP stripped |
| `SB_AGENT_CODEX_SKIP_MCP` | 1 when lightweight | Faster child boot |
| `--use-exec` | off | Headless fallback after TUI stall |

Fixture / live-test only: set `SB_AGENT_<HOST>_FIXTURE=1`, `SB_AGENT_<HOST>_LIGHTWEIGHT=0` when full MCP boot is required.

### 6. Supervision model (in SKILL.md)

- [ ] Brief → Launch → Checkpoint 1 (ack) → Checkpoint 2 (idle watch) → Complete → Mentor note
- [ ] Escalation ladder rows: **stuck**, **quota**, **auth**, **hook-trust** (if applicable), **harness**, **product** (+ host-specific: model-policy, log-floor)
- [ ] Parent must not implement delegated work in parallel on same files

### 7. Ship gates (before merge to `main`)

- [ ] **Thermo-nuclear review** — launch `thermo-nuclear-review-subagent` on branch diff; address or waive with evidence
- [ ] **Thermo-nuclear code quality** — launch `thermo-nuclear-code-quality-review-subagent` on maintainability / 1k-line rule
- [ ] **Security review** — run `security-review` subagent on delegate wrapper + adapter changes; no medium+ issues
- [ ] **Sentinel re-audit** — when skill/harness touches `hooks/`, `scripts/`, enforcement surfaces
- [ ] **Real smoke test** on **isolated** `enterprise-grade-test-app` branch (or host worktree per §9):
  - Parent writes brief under `.planning/agent-<host>/smoke/`
  - Run `bash scripts/agent-<host>-delegate.sh --work-dir <fixture> --brief-file ... --log ...` (**absolute log/brief paths**)
  - Verify commit SHA + acceptance criteria + log bytes (host-specific floor if any)
  - Record `result.md` with PASS/FAIL and `failure_class`
- [ ] Do **not** claim PASS on timeout-only logs or parent-routing-only with zero worker delta

### 8. Structural test

- [ ] `tests/scripts/test-agent-<host>-skill.sh` — grep-based contract mirroring [`test-agent-codex-skill.sh`](../../tests/scripts/test-agent-codex-skill.sh)
- [ ] Asserts: SKILL frontmatter, route, matrix exclusion docs, delegate references, wrapper sources live adapter, lightweight/orchestrator env, `bash -n` on wrapper
- [ ] Host-specific: Cursor → `composer-2.5`, `CURSOR_API_KEY`, `stream-json`, log floor; Codex → `codex-interactive-invoke.py`, lightweight env
- [ ] Wire into CI if sibling tests are listed in `tests/run-all-tests.sh` or targeted pre-merge script
- [ ] **Gap (open):** add orchestrator parent guard case to `tests/hooks/test-orchestrator-parent-guard.sh` allowing `agent-<host>-delegate.sh` Bash

### 9. Sync generated surfaces

```bash
bash scripts/sync-codex-package.sh    # agents/, host-bundles/, plugins/silver-bullet/skill-source/
bash scripts/generate-plugin-commands.sh  # only if adding a new top-level composer route (agent-* skills are Skill-tool-only)
bash -n scripts/agent-<host>-delegate.sh
bash tests/scripts/test-agent-<host>-skill.sh
graphify update .
```

- [ ] `.gitignore` entry for `.planning/agent-<host>/`
- [ ] `.planning/silver-agent-<host>-pilot.md` — pilot PASS summary (no secrets)
- [ ] agentmemory: pilot outcome, failure classes, mentor note

**Do not commit:** `.planning/agent-<host>/**/*.log` — may contain secrets.

---

## Per-host variation table

| Dimension | Codex | Claude | Cursor | Fourth host |
|-----------|-------|--------|--------|-------------|
| **Invoke CLI** | `codex` (TUI / `codex exec`) | `claude` (expect TUI / print) | `cursor-agent` headless | `<cli>` |
| **Harness script** | `codex-interactive-invoke.py` | `claude-interactive-invoke.expect` | inline in `agent.sh` + stream-json | TBD |
| **Work dir env** | `CODEX_WORK_DIR` | `CLAUDE_WORK_DIR` | `CURSOR_WORK_DIR` | `<HOST>_WORK_DIR` |
| **SB_ROOT** | SB checkout with full `tests/live/` | same | same | same |
| **Child route syntax** | `$sb:*` | `/sb:*` or `[$silver]` | `/sb:*` | host picker |
| **CWD policy** | `cd "$CODEX_WORK_DIR"` in harness | `cd "$CLAUDE_WORK_DIR"` | `cd "$CURSOR_WORK_DIR"` | `cd "$WORK_DIR"` |
| **Auth** | Codex login / API in `CODEX_HOME` | OAuth; `claude-matrix-auth.sh` | Keychain `cursor-agent login`; no `CURSOR_API_KEY` | TBD |
| **Lightweight hook** | Ephemeral `CODEX_HOME`, MCP strip | Fresh runtime state dir optional | `SB_LIVE_CURSOR_FORCE_HEADLESS=1`, stream-json | TBD |
| **Headless fallback** | `--use-exec` | print mode when expect unavailable | default headless | TBD |
| **Matrix lock file** | `.e2e-live-test-codex.lock` | `.e2e-live-test.lock` | `.e2e-live-test-cursor.lock` | `.e2e-live-test-<host>.lock` |
| **Fixture branch** | `enterprise-e2e/round-N-codex` | `round6` / host branch | `enterprise-e2e/round-N-cursor` worktree | per §9 |
| **Quota env** | `AGENT_CODEX_QUOTA_RETRY_*` | `AGENT_CLAUDE_QUOTA_RETRY_*` | `AGENT_CURSOR_QUOTA_RETRY_*` | `AGENT_<HOST>_QUOTA_RETRY_*` |
| **Log evidence** | exit 0 + redacted log | expect log file | `SB_AGENT_CURSOR_LOG_FLOOR` (2048 B) | define floor |
| **Model policy** | `CODEX_MODEL` optional | `CLAUDE_MODEL` default sonnet | **`composer-2.5` mandatory** | TBD |
| **Log/brief paths** | absolute in wrapper | absolute in wrapper | absolute in wrapper (pilot fix) | absolute in wrapper |

---

## E2E session learnings to embed (091–115, §5a/§5b adapted)

Adapt matrix certification lessons for **production delegation** — do not copy row gates verbatim.

| ID / lesson | Production delegation adaptation |
|-------------|----------------------------------|
| E2E-091 | Routing-only parent work ≠ worker delta — require product evidence |
| E2E-093 | stream-json + log floor — short summary-only logs FAIL without composite evidence |
| E2E-095 | Brownfield: document FORCE/waiver with file:line pre-existence proof |
| E2E-100 | Internal harness rows N/A — single-task delegation has no parent-chain exempt |
| E2E-101 | Never checkout fixture to sibling host branch mid-delegation — use dedicated worktree |
| E2E-103 / E2E-114 | **Committed product delta** when brief requires code change — dirty tree alone insufficient |
| E2E-105 | Fresh `${SB_RUNTIME_STATE_DIR}` per Claude delegation wave when matrix parity needed |
| E2E-107 | Bracketed-paste / submit stalls — if log stops at `Queued follow-up`, re-invoke with harness fix (Codex/Claude) |
| E2E-108 | Codex lightweight delegate: hook-trust seed only — not full install each invocation |
| E2E-109 | Export fixture/test-app root before any mkdir in pilot setup |
| E2E-110 | Claude: no inherit-keys shortcuts in production delegate — document auth policy |
| E2E-112 | Rescore ≠ live rerun — harness fix requires new delegate invocation for credit |
| Keychain Cursor auth | `"apiKeySource":"login"` in log — not API key |
| Composer 2.5 only | Reject fast model in wrapper |
| Stdout buffering | 0 B log growth up to ~30 min possible — do not PASS on timeout-only |
| Absolute log paths | Canonicalize in wrapper (cursor pilot fix @ [`7a901af4`](https://github.com/alo-exp/silver-bullet/commit/7a901af4)) |
| Inherited baseline | Pre-existing fixture artifacts disqualify authorship claims |
| Honest baseline | `09f8d1a` — not pre-seeded `8482e60` (methodology §5a #1) |

---

## Orchestrator integration gaps (document + track)

| Gap | Status | Action |
|-----|--------|--------|
| `agent-delegate-common.sh` | Open | Extract shared quota/redaction/header from cursor + codex wrappers |
| Bash allowlist substring | Open | `sb_orchestrator_parent_bash_allowed` matches `*agent-*-delegate.sh*` — tighten to parsed argv |
| Parent guard test | Open | Add case to `tests/hooks/test-orchestrator-parent-guard.sh` allowing `agent-<host>-delegate.sh` Bash |

---

## Anti-patterns (do not copy from E2E matrix)

| Anti-pattern | Why |
|--------------|-----|
| Setting `SB_E2E_ENTERPRISE_MATRIX=1` in delegate wrapper | Turns on ledger, row writers, matrix timeouts — not single-task delegation |
| Loading `SB_E2E_LEDGER_FILE`, batch PID files, matrix quiesce | Operator certification artifacts |
| Copying §5b product gates verbatim into SKILL.md | Adapt completion criteria for production delegation; cite §5b as methodology reference only |
| Session-persisting delegation state like Sidekick | Each `/sb:agent-<host>` invocation must tear down |
| Parent implementing delegated edits in parallel | Violates orchestrator parent contract |
| `pkill` / removing another host's lock files | §9 cross-agent isolation |
| Committing `.planning/agent-<host>/*.log` | May contain secrets — gitignore only |
| Duplicating invoke logic instead of sourcing `tests/live/agents/<host>/agent.sh` | Drift from live certification harness |
| Using `composer-2.5-fast` for Cursor delegation | Global subagent policy violation |
| Relative `--log` / `--brief-file` paths | Resolve under `WORK_DIR`, not SB_ROOT — use absolute paths |

---

## Reviews

Run on **SB-repo harness/skill changes** before merge (not on every product delegation).

| Gate | When | Pass criteria |
|------|------|---------------|
| **thermo-nuclear-code-quality-review** | New/changed delegate wrapper, adapter hooks, skill >~100 LOC net | No maintainability blockers; no race in log header; DRY follow-up noted |
| **thermo-nuclear-review** | Same diff | Approve with fixes: gitignore, matrix env unset, policy env always-on |
| **security-review** | Same diff | No medium+ issues; log redaction + gitignore for `.planning/agent-<host>/` |
| **Sentinel re-audit** | Skill/harness touches `hooks/`, `scripts/`, enforcement | Re-run Sentinel audit or confirm no new enforcement bypass |

Product-only commits on test-app branch do not require SB-repo review ladder — parent verifies acceptance criteria locally.

---

## Pilot

Real-life pilot before claiming production-ready for a new host.

### Pilot setup

| Item | Value |
|------|-------|
| SB branch | Feature branch (e.g. `feature/silver-agent-<host>-skill`) |
| Test app | Isolated worktree (e.g. `enterprise-grade-test-app-cursor`) |
| Test app branch | `round-agent-<host>-test` or `feature/<pilot-slug>` |
| Task scope | Small real delta — doc marker or single API endpoint |
| Log path | `.planning/agent-<host>/pilot-YYYYMMDD/<host>-run.log` (gitignored) |
| Report | `.planning/silver-agent-<host>-pilot.md` (committed summary, no secrets) |

Use **dedicated worktree** when shared clone is dirty on another branch ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)). Branch naming: `feature/<task-slug>` or pilot `round-agent-<host>-test` — never stomp sibling host branches.

### Pilot brief example

Single doc edit: add pilot marker line to `README.md`; commit `docs: agent-<host> pilot marker`.

### §5b gates adapted for production delegation (PASS checklist)

Delegation is **PASS** only when **all** hold:

1. `agent-<host>-delegate.sh` exits **0** without harness `ERROR:`.
2. **Log floor** — log size ≥ `SB_AGENT_<HOST>_LOG_FLOOR` (Cursor default 2048 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. **Live session evidence** — log shows model/session markers (e.g. Cursor `Composer 2.5`, `"apiKeySource":"login"`).
4. **Every acceptance criterion** verified with evidence (commit SHA, test output, file paths).
5. **Committed product delta** when brief requires code change — dirty tree alone insufficient.
6. Parent summary in `.planning/agent-<host>/<task-id>/result.md` or agentmemory.
7. `graphify update .` in repos the worker modified (when graphify enabled).

**FAIL** — record `failure_class`: `stuck` | `quota` | `auth` | `model-policy` | `hook-trust` | `harness` | `product` | `log-floor`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

### Pilot invocation (Cursor reference)

```bash
export SB_ROOT=/path/to/silver-bullet/repo
export CURSOR_AGENT_TIMEOUT=600
export SB_AGENT_CURSOR_LOG_FLOOR=512   # lower only for smoke; production default 2048

bash scripts/agent-cursor-delegate.sh \
  --work-dir /path/to/enterprise-grade-test-app-cursor \
  --brief-file "$SB_ROOT/.planning/agent-cursor/pilot-YYYYMMDD/brief.md" \
  --log "$SB_ROOT/.planning/agent-cursor/pilot-YYYYMMDD/cursor-run.log"
```

---

## Quick reference — cursor vs codex shipped

| Concern | Cursor | Codex |
|---------|--------|-------|
| Wrapper | `scripts/agent-cursor-delegate.sh` | `scripts/agent-codex-delegate.sh` |
| Work dir env | `CURSOR_WORK_DIR` / `--work-dir` | `CODEX_WORK_DIR` / `--work-dir` |
| Log floor | `SB_AGENT_CURSOR_LOG_FLOOR` (2048) | — (add if needed) |
| Headless flag | `SB_LIVE_CURSOR_FORCE_HEADLESS=1` | `--use-exec` fallback |
| Model policy | `composer-2.5` mandatory | `CODEX_MODEL` optional |
| Auth | Keychain; unset `CURSOR_API_KEY` | Hook trust + native CLI |
| Route syntax | `/sb:*` | `$sb:*` |
| stream-json | `SB_AGENT_CURSOR_STREAM_JSON=1` | N/A |

---

## Prompt for Claude agent

```markdown
You are building `/sb:agent-claude` in the Silver Bullet repo (`/Users/shafqat/projects/silver-bullet/repo`).

**Mission:** On-demand, single-task delegation from a parent host (Cursor, Codex, or Claude parent) to **Claude TUI** as executor — parent supervises (brief → checkpoint → escalate); Claude implements in `CLAUDE_WORK_DIR`. NOT Sidekick session mode. NOT enterprise E2E matrix.

**Read first (graphify query before grep):**
- `skills/silver-agent-codex/SKILL.md` — canonical pattern
- `scripts/agent-codex-delegate.sh` — wrapper shape
- `tests/live/agents/claude/agent.sh` — reuse this adapter
- `scripts/claude-interactive-invoke.expect`
- `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` — full checklist

**Deliverables:**
1. `skills/silver-agent-claude/SKILL.md` — mirror codex structure; Claude-specific env (`CLAUDE_WORK_DIR`, expect invoke, `/sb:*` routes, OAuth auth policy)
2. `scripts/agent-claude-delegate.sh` — sources `tests/live/agents/claude/agent.sh`; lightweight defaults (`SB_ORCHESTRATOR_WORKER=1`, `RTK_DISABLED=1`, quota retry); no matrix env; absolute log/brief paths
3. Router: `skills/silver/SKILL.md` row, `hooks/lib/orchestrator-parent.sh` allowlist, `tests/integration/test-skill-execution-paths.sh` case
4. `tests/scripts/test-agent-claude-skill.sh` — structural contract
5. `.gitignore` → `.planning/agent-claude/`
6. `bash scripts/sync-codex-package.sh`
7. Real smoke: isolated test-app branch, brief + delegate + commit evidence → `.planning/agent-claude/smoke/result.md`

**Ship gates:** Thermo dual review + security-review + Sentinel on diff; smoke PASS with commit SHA.

**Anti-patterns:** No `SB_E2E_ENTERPRISE_MATRIX`, no ledger, no session persistence, no parallel parent edits on delegated files.

Return: changed file list + smoke commit SHA + structural test output.
```

---

## Prompt for Cursor agent

```markdown
You are extending or verifying `/sb:agent-cursor` in the Silver Bullet repo (`/Users/shafqat/projects/silver-bullet/repo`).

**Mission:** On-demand, single-task delegation from a parent host (Claude, Codex, or Cursor parent) to **cursor-agent** headless CLI as executor — parent supervises (brief → checkpoint → escalate); Cursor implements in `CURSOR_WORK_DIR`. NOT Sidekick session mode. NOT enterprise E2E matrix.

**Read first (graphify query before grep):**
- `skills/silver-agent-codex/SKILL.md` — canonical pattern (merged @ 83e42c34)
- `skills/silver-agent-cursor/SKILL.md` — Cursor sibling
- `scripts/agent-cursor-delegate.sh`, `tests/live/agents/cursor/agent.sh`
- `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` — full checklist

**If skill missing, deliver:**
1. `skills/silver-agent-cursor/SKILL.md` — headless `cursor-agent`, Keychain auth (unset `CURSOR_API_KEY`), `composer-2.5` only, stream-json log capture, `SB_AGENT_CURSOR_LOG_FLOOR`
2. `scripts/agent-cursor-delegate.sh` — sources live adapter; `SB_LIVE_CURSOR_FORCE_HEADLESS=1`; orchestrator worker bypass; absolute log/brief paths
3. Router: `skills/silver/SKILL.md` row, `hooks/lib/orchestrator-parent.sh`, `tests/integration/test-skill-execution-paths.sh`
4. `tests/scripts/test-agent-cursor-skill.sh`
5. `.gitignore` → `.planning/agent-cursor/`
6. `bash scripts/sync-codex-package.sh`
7. Real smoke on isolated worktree (`enterprise-grade-test-app-cursor` per TEST-APP-BRANCH-POLICY) → `.planning/agent-cursor/smoke/result.md`

**Ship gates:** Thermo dual review + security-review; smoke PASS with log ≥ 2048 B and commit SHA.

**Anti-patterns:** No matrix ledger, no IDE in-session mode in delegate default, no `composer-2.5-fast`, no `CURSOR_API_KEY` in delegate, no relative log paths.

Return: changed file list + smoke evidence + structural test output.
```

---

## Prompt for fourth host agent (`<HOST4>`)

```markdown
You are building `/sb:agent-<HOST4>` in the Silver Bullet repo.

Follow `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md` end-to-end. Use `skills/silver-agent-codex/SKILL.md` + `scripts/agent-codex-delegate.sh` as the template.

**Prerequisites:** `tests/live/agents/<HOST4>/agent.sh` must implement `agent_name`, `agent_preflight`, `agent_invoke` (see codex/claude/cursor adapters).

**Mission:** Per-task on-demand delegation only — not Sidekick, not E2E matrix.

**Deliverables:** SKILL.md, agent-<HOST4>-delegate.sh, structural test, router registration, sync-codex-package.sh, isolated smoke on dedicated fixture branch/worktree, Thermo + security-review + Sentinel reviews.

Return: file list + smoke commit SHA.
```

---

## Version history

| Date | Change |
|------|--------|
| 2026-07-04 | Initial meta-prompt on `main` @ 6b0d14b2; codex reference @ 83e42c34; cursor/claude/HOST4 stubs |
| 2026-07-04 | Merged cursor-session enhancements: §5b pilot gates, E2E-091–115 adaptations, stream-json/Keychain/composer-2.5, absolute log paths, reviews ladder, orchestrator gaps, agent-delegate-common follow-up |
