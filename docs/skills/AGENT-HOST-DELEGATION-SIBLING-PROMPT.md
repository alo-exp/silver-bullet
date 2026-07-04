# Agent-Host Delegation — Sibling Skill Authoring Prompt

Reusable authoring prompt for **`/silver:agent-{host}`** skills: on-demand, parent-supervised delegation of a **single real task** to a host agent TUI/CLI as a subagent. Not session-persistent like Sidekick. Not enterprise E2E matrix certification.

**Canonical implementations:** [`skills/silver-agent-cursor/SKILL.md`](../../skills/silver-agent-cursor/SKILL.md), [`skills/silver-agent-codex/SKILL.md`](../../skills/silver-agent-codex/SKILL.md)  
**Pilot evidence:** [`.planning/silver-agent-cursor-pilot.md`](../../.planning/silver-agent-cursor-pilot.md)

---

## Purpose

### What this pattern is

| Property | Value |
|----------|-------|
| **Activation** | Per task — brief → invoke → verify → tear down |
| **Parent role** | Supervisor: brief, checkpoints, escalation, mentor note, evidence capture |
| **Worker role** | Target host TUI/CLI executes in `--work-dir` (real product CWD) |
| **Route** | `/silver:agent-{host}` (Cursor/Claude picker) or `$silver:agent-{host}` (Codex picker) |
| **Skill dir** | `skills/silver-agent-{host}/` (`name: silver-agent-{host}`) |
| **Harness** | `scripts/agent-{host}-delegate.sh` → `tests/live/agents/{host}/agent.sh` |

### What this pattern is not

| Anti-pattern | Use instead |
|--------------|-------------|
| Session-persistent quality gates across turns | **Sidekick** (`${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`) |
| Enterprise E2E matrix rows / ledger / §5b row scoring | Matrix harness (`run-enterprise-e2e-matrix.sh`, `cursor3-real-driver.sh`, …) |
| Parent implements delegated work in parallel | Parent supervises only; worker owns product delta |
| Host `Task` workers for the delegated product task | Delegate wrapper sets `SB_ORCHESTRATOR_WORKER=1` in child |

### Original user intent (carry forward)

1. **Stand-alone per-task skill** — not session-persistent like Sidekick.
2. **Drive host TUI as subagent from any host-agent** — Claude parent → Cursor worker, Cursor parent → Codex worker, etc.
3. **Arbitrary real work** — not the E2E matrix row catalog.
4. **Review ladder before ship** — thermo-nuclear code-quality + thermo-nuclear review + security-review + Sentinel re-audit on SB-repo harness changes.
5. **Real-life pilot** — isolated test-app branch/worktree with committed product delta.
6. **Name pattern** — `/silver:agent-{host}` everywhere (router, skill frontmatter, delegate script comments).

### Sidekick supervision borrow (without persistence)

Borrow Sidekick’s **advisor–mentor** lifecycle for a **single task**:

| Phase | Parent | Persisted? |
|-------|--------|------------|
| Brief | Task + acceptance criteria + constraints | Optional `.planning/agent-{host}/<task-id>/brief.md` |
| Launch | Run `agent-{host}-delegate.sh`; tail log | Log only (gitignored) |
| Checkpoint 1 | Worker acknowledged prompt (log growth / submit marker) | — |
| Checkpoint 2 | Idle >5 min without log growth → prepare escalation | — |
| Complete | Verify acceptance criteria vs git/test/commit | `result.md` or agentmemory |
| Mentor note | Short retrospective for next delegation | agentmemory only |

Do **not** write session markers to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` or quality-gate-state.

---

## Prerequisites

Before authoring a new `silver-agent-{host}` sibling:

| Prerequisite | Check |
|--------------|-------|
| Live adapter exists | `tests/live/agents/{host}/agent.sh` with `agent_preflight` + `agent_invoke` |
| Host CLI on PATH | `cursor-agent`, native Codex CLI, etc. |
| Router entry | `skills/silver/SKILL.md` intent table row for `silver:agent-{host}` |
| Orchestrator allowlist | `hooks/lib/orchestrator-parent.sh` → `sb_orchestrator_parent_skill_allowed` includes `silver-agent-{host}` |
| Parent Bash bridge | Same file → `sb_orchestrator_parent_bash_allowed` allows `agent-{host}-delegate.sh` |
| Integration alias | `tests/integration/test-skill-execution-paths.sh` `resolve_silver_alias` case |
| Logs gitignored | `.gitignore` → `.planning/agent-{host}/` |
| Methodology literacy | [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a/§5b/§8 — adapt for production delegation, do not copy matrix row gates verbatim |
| Host readiness audit | Pattern: [CURSOR-METHODOLOGY-HARNESS-READINESS-AUDIT.md](../testing/CURSOR-METHODOLOGY-HARNESS-READINESS-AUDIT.md), [CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md](../testing/CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md) |

**Composer 2.5 policy (Cursor only, mandatory):** Subagent/delegation work uses **`composer-2.5` only**. Never `composer-2.5-fast`. Enforce in delegate wrapper (`CURSOR_AGENT_MODEL`, reject `*fast*`), skill doc, and parent brief.

---

## Skill anatomy

### Frontmatter template

```yaml
---
name: silver-agent-{host}
description: On-demand parent-supervised delegation of a single real task to {Host} TUI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent should supervise while {Host} executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---
```

### Required sections (in order)

1. **Title** — `# /silver:agent-{host} — {Host} Subagent Delegation`
2. **Contrast with Sidekick** — per-task vs session-persistent
3. **Contrast with E2E matrix** — reuses live adapter; excludes matrix env/ledger
4. **When to use** — table: delegate vs inline/Task/orchestrator queue
5. **Roles** — parent supervisor vs worker executor
6. **Activation** — on-demand 4-step lifecycle
7. **Parent orchestrator rules** — parent may invoke skill + delegate.sh; must not edit delegated product
8. **Step 1 — Brief** — markdown template + graphify + agentmemory
9. **Step 2 — Environment** — fixture vs real project table + harness env + auth policy
10. **Step 3 — Invoke** — `agent-{host}-delegate.sh` examples (absolute paths for `--log` / `--brief-file`)
11. **Step 4 — Supervision** — checkpoints + failure escalation ladder with `failure_class` values
12. **Step 5 — Completion criteria** — §5b-adapted PASS gates (see below)
13. **Step 6 — Capture** — agentmemory + graphify
14. **When parent should not delegate**
15. **References** — harness, adapter, methodology audits; matrix paths marked “matrix only”

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

### Host-specific route syntax

| Host | Prompt route prefix |
|------|---------------------|
| Cursor | `/silver:*` |
| Codex | `$silver:*` |
| Claude | `$silver:*` or host-native equivalent |
| Future (Gemini, etc.) | Document in skill after adapter exists |

### Auth model per host

| Host | Auth | Forbidden / pitfalls |
|------|------|----------------------|
| **Cursor** | Keychain via `cursor-agent login`; preflight `agent_preflight` | **Do not** set `CURSOR_API_KEY` — bypasses Keychain, breaks cert parity (methodology §8) |
| **Codex** | Native CLI session + hook trust | Use `CODEX_AUTO_TRUST_HOOKS=1`, `CODEX_BYPASS_HOOK_TRUST=1` in lightweight delegate; seed via `bash scripts/install-codex.sh --hook-trust-seed-only` on trust failure |
| **Claude** (future) | API key / OAuth per Claude Code docs | Isolate state per delegation wave; no matrix inherit-keys shortcuts |
| **Gemini** (future) | TBD when adapter lands | Document in skill before ship |

### Matrix env exclusion (all hosts)

Delegate wrapper **must** `unset` inherited matrix env:

- `SB_E2E_ENTERPRISE_MATRIX`
- `SB_E2E_LEDGER_FILE`
- `SB_E2E_MATRIX_BATCH_PID`

Never load matrix ledger, row outcome writers, or fixture branch locks for normal delegation.

---

## Harness

### File layout

| Artifact | Path | Notes |
|----------|------|-------|
| Skill (source) | `skills/silver-agent-{host}/SKILL.md` | Authoring source of truth |
| Delegate wrapper | `scripts/agent-{host}-delegate.sh` | Executable; `bash -n` clean |
| Live adapter | `tests/live/agents/{host}/agent.sh` | Shared with live tests; sourced by wrapper |
| Shared lib (follow-up) | `scripts/lib/agent-delegate-common.sh` | **Gap:** extract quota retry, redaction, log header from cursor/codex wrappers |
| Structural test | `tests/scripts/test-agent-{host}-skill.sh` | Grep contract on skill + wrapper |
| Claude bundle | `agents/claude/silver:agent-{host}/SKILL.md` | Generated |
| Codex/Cursor bundles | `host-bundles/{codex,cursor}/silver-agent-{host}/SKILL.md` | Generated |
| Plugin skill-source | `plugins/silver-bullet/skill-source/silver-agent-{host}/SILVER_SOURCE` | Generated |

### Delegate wrapper contract

Every `agent-{host}-delegate.sh` should implement:

```
Usage: agent-{host}-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--sb-root PATH] [host-specific flags]
```

| Behavior | Requirement |
|----------|-------------|
| Work dir validation | `--work-dir` must exist |
| Prompt sources | `--prompt`, `--prompt-file`, or `--brief-file` (mutually exclusive content path) |
| Path canonicalization | **Absolute paths** for `--log` and `--brief-file` (pilot lesson: relative paths resolve under `WORK_DIR`) |
| Adapter source | `source "${SB_ROOT}/tests/live/agents/{host}/agent.sh"` |
| Matrix env | `unset` inherited matrix variables at start |
| Lightweight child | `SB_ORCHESTRATOR_WORKER=1`, `SB_ORCHESTRATOR_PARENT=0` so hooks do not spawn parent Task workers |
| RTK | `RTK_DISABLED=1` during invoke for readable ops logs |
| Quota retry | `AGENT_{HOST}_QUOTA_RETRY_INTERVAL` (60), `AGENT_{HOST}_QUOTA_RETRY_MAX` (5) |
| Log redaction | Post-process secrets (`api_key`, `sk-`, `ghp_`) before parent reads log |
| Log gitignore | Write under `.planning/agent-{host}/` only |

### Host-specific harness env (reference)

**Cursor** (`agent-cursor-delegate.sh`):

| Env | Default | Purpose |
|-----|---------|---------|
| `CURSOR_AGENT_TIMEOUT` | 1800 | Hard timeout (E2E-087/092) |
| `CURSOR_AGENT_MODEL` / `CURSOR_MODEL` | `composer-2.5` | Model policy |
| `SB_AGENT_CURSOR_STREAM_JSON` | 1 | stream-json capture (E2E-093) |
| `SB_AGENT_CURSOR_LOG_FLOOR` | 2048 | Minimum log bytes for PASS |
| `SB_LIVE_CURSOR_FORCE_HEADLESS` | 1 | `cursor-agent` CLI, not IDE session |
| `SB_AGENT_CURSOR_LIGHTWEIGHT` | 1 | Strip orchestrator parent context |

**Codex** (`agent-codex-delegate.sh`):

| Env | Default | Purpose |
|-----|---------|---------|
| `CODEX_INTERACTIVE_READY_TIMEOUT` | 120 via delegate | Model/MCP boot |
| `CODEX_INTERACTIVE_IDLE_TIMEOUT` | 3600 via delegate | Idle watchdog |
| `SB_AGENT_CODEX_LIGHTWEIGHT` | 1 | Ephemeral `CODEX_HOME`, MCP stripped |
| `SB_AGENT_CODEX_SKIP_MCP` | 1 when lightweight | Faster child boot |
| `--use-exec` | off | Headless fallback after TUI stall |

### Worktree / branch policy

- Use **dedicated worktree** when shared clone is dirty on another branch ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
- Branch naming: `feature/<task-slug>` or pilot `round-agent-{host}-test` — never stomp sibling host branches.
- Honest baseline for certification-style work: `09f8d1a` — not pre-seeded `8482e60` (methodology §5a #1).

### E2E session learnings to embed (091–115, §5a/§5b adapted)

| ID / lesson | Production delegation adaptation |
|-------------|----------------------------------|
| E2E-091 | Routing-only parent work ≠ worker delta — require product evidence |
| E2E-093 | stream-json + log floor — short summary-only logs FAIL without composite evidence |
| E2E-095 | Brownfield: document FORCE/waiver with file:line pre-existence proof |
| E2E-100 | Internal harness rows N/A — single-task delegation has no parent-chain exempt |
| Keychain Cursor auth | `apiKeySource":"login"` in log — not API key |
| Composer 2.5 only | Reject fast model in wrapper |
| Stdout buffering | 0 B log growth up to ~30 min possible — do not PASS on timeout-only |
| Absolute log paths | Canonicalize in wrapper (cursor pilot fix) |
| Inherited baseline | Pre-existing fixture artifacts disqualify authorship claims |
| Rescore ≠ live rerun | Harness fix requires new delegate invocation for credit |

### Orchestrator integration gaps (document + track)

| Gap | Status | Action |
|-----|--------|--------|
| `agent-delegate-common.sh` | Open | Extract shared quota/redaction/header from cursor + codex wrappers |
| Bash allowlist substring | Open | `sb_orchestrator_parent_bash_allowed` matches `*agent-*-delegate.sh*` — tighten to parsed argv |
| Parent guard test | Open | Add case to `tests/hooks/test-orchestrator-parent-guard.sh` allowing `agent-{host}-delegate.sh` Bash |

---

## Reviews

Run on **SB-repo harness/skill changes** before merge (not on every product delegation).

| Gate | When | Pass criteria |
|------|------|---------------|
| **thermo-nuclear-code-quality-review** | New/changed delegate wrapper, adapter hooks, skill >~100 LOC net | No maintainability blockers; no race in log header; DRY follow-up noted |
| **thermo-nuclear-review** | Same diff | Approve with fixes: gitignore, matrix env unset, policy env always-on |
| **security-review** | Same diff | No medium+ issues; log redaction + gitignore for `.planning/agent-{host}/` |
| **Sentinel re-audit** | Skill/harness touches `hooks/`, `scripts/`, enforcement | Re-run Sentinel audit or confirm no new enforcement bypass |

Product-only commits on test-app branch do not require SB-repo review ladder — parent verifies acceptance criteria locally.

---

## Pilot

Real-life pilot before claiming production-ready for a new host.

### Pilot setup

| Item | Value |
|------|-------|
| SB branch | Feature branch (e.g. `feature/silver-agent-codex-skill`) |
| Test app | Isolated worktree (e.g. `enterprise-grade-test-app-cursor`) |
| Test app branch | `round-agent-{host}-test` or `feature/<pilot-slug>` |
| Task scope | Small real delta — doc marker or single API endpoint |
| Log path | `.planning/agent-{host}/pilot-YYYYMMDD/cursor-run.log` (gitignored) |
| Report | `.planning/silver-agent-{host}-pilot.md` (committed summary, no secrets) |

### Pilot brief example

Single doc edit: add pilot marker line to `README.md`; commit `docs: agent-{host} pilot marker`.

### §5b gates adapted for production delegation (PASS checklist)

Delegation is **PASS** only when **all** hold:

1. `agent-{host}-delegate.sh` exits **0** without harness `ERROR:`.
2. **Log floor** — log size ≥ `SB_AGENT_{HOST}_LOG_FLOOR` (Cursor default 2048 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. **Live session evidence** — log shows model/session markers (e.g. Cursor `Composer 2.5`, `apiKeySource":"login"`).
4. **Every acceptance criterion** verified with evidence (commit SHA, test output, file paths).
5. **Committed product delta** when brief requires code change — dirty tree alone insufficient.
6. Parent summary in `.planning/agent-{host}/<task-id>/result.md` or agentmemory.
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

## Sync commands

After editing `skills/silver-agent-{host}/SKILL.md`:

```bash
# Regenerate agent bundles + plugin skill-source
bash scripts/sync-codex-package.sh

# Composer command stubs (if top-route discoverability needed)
bash scripts/generate-plugin-commands.sh

# Shell syntax
bash -n scripts/agent-{host}-delegate.sh

# Structural contract
bash tests/scripts/test-agent-{host}-skill.sh

# Optional: integration skill paths
bash tests/integration/test-skill-execution-paths.sh

# Keep graph current after code edits
graphify update .
```

---

## Test requirements

### Structural test (`tests/scripts/test-agent-{host}-skill.sh`)

Minimum grep/syntax checks:

- [ ] `SKILL.md` exists; `name: silver-agent-{host}`; `user-invocable: true`
- [ ] Route `/silver:agent-{host}` documented
- [ ] References `agent-{host}-delegate.sh` and live adapter
- [ ] Excludes / warns on `SB_E2E_ENTERPRISE_MATRIX`
- [ ] Documents `agentmemory` + `graphify`
- [ ] Host-specific: Cursor → `composer-2.5`, `CURSOR_API_KEY`, `stream-json`, log floor
- [ ] Host-specific: Codex → `codex-interactive-invoke.py`, lightweight env, model-ready timeout
- [ ] Wrapper executable; `bash -n` pass; quota retry; orchestrator worker bypass; matrix env unset

### Orchestrator parent guard (gap — add when shipping)

```bash
# Expected addition to tests/hooks/test-orchestrator-parent-guard.sh
out_delegate=$(... Bash ... "bash scripts/agent-cursor-delegate.sh --work-dir /tmp ...")
assert_empty "parent allows agent-cursor-delegate.sh"
```

### Doc / repo tests

No dedicated `docs/skills` freshness test today. Run targeted tests above before commit. Full suite: `bash tests/run-all-tests.sh` (release path).

---

## Commit checklist

Before merging a new `silver-agent-{host}` sibling:

### Source files

- [ ] `skills/silver-agent-{host}/SKILL.md`
- [ ] `scripts/agent-{host}-delegate.sh` (executable)
- [ ] `tests/live/agents/{host}/agent.sh` (if adapter changes needed)
- [ ] `skills/silver/SKILL.md` — router intent row
- [ ] `hooks/lib/orchestrator-parent.sh` — skill + Bash allowlist
- [ ] `tests/integration/test-skill-execution-paths.sh` — alias case
- [ ] `tests/scripts/test-agent-{host}-skill.sh`
- [ ] `.gitignore` — `.planning/agent-{host}/`
- [ ] `.planning/silver-agent-{host}-pilot.md` — pilot PASS summary (no secrets)

### Generated surfaces (via sync)

- [ ] `host-bundles/codex/silver-agent-{host}/SKILL.md`
- [ ] `host-bundles/cursor/silver-agent-{host}/SKILL.md`
- [ ] `agents/claude/silver:agent-{host}/SKILL.md`
- [ ] `plugins/silver-bullet/skill-source/silver-agent-{host}/SILVER_SOURCE`

### Quality gates

- [ ] `bash tests/scripts/test-agent-{host}-skill.sh` — PASS
- [ ] `bash -n scripts/agent-{host}-delegate.sh` — PASS
- [ ] Pilot §5b gates — PASS with commit SHA on test-app branch
- [ ] thermo-nuclear code-quality + thermo-nuclear review + security-review — no open blockers
- [ ] Sentinel re-audit if enforcement surface touched
- [ ] `graphify update .` after code edits
- [ ] agentmemory: pilot outcome, failure classes, mentor note

### Do not commit

- `.planning/agent-{host}/**/cursor-run.log` (or codex-run.log) — may contain secrets
- Test-app pilot markers unless that repo’s policy allows

---

## Future hosts (Claude, Gemini, …)

When adding `silver-agent-claude` or `silver-agent-gemini`:

1. Land `tests/live/agents/{host}/agent.sh` first (live test green).
2. Copy this prompt’s skill anatomy; fill auth table row.
3. Implement `agent-{host}-delegate.sh` — prefer `agent-delegate-common.sh` once extracted.
4. Add orchestrator allowlist + integration alias + structural test.
5. Run pilot on isolated test-app worktree; publish `.planning/silver-agent-{host}-pilot.md`.
6. Sync bundles; open PR with review ladder evidence.

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
| Route syntax | `/silver:*` | `$silver:*` |
