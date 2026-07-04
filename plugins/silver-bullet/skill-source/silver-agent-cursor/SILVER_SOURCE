---
name: "silver:agent-cursor"
title: "Agent Cursor"
description: On-demand parent-supervised delegation of a single real task to Cursor agent TUI (cursor-agent) as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Claude, Codex, or Cursor parent) should supervise while cursor-agent executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---

# /silver:agent-cursor — Cursor Agent TUI Subagent Delegation

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **cursor-agent** executes in the target project working directory.

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor-mentor). This skill activates **per task** and tears down when the task completes or escalates. It borrows Sidekick's supervision patterns — brief → checkpoint → failure ladder → mentor note — without persisting gate state across sessions.

**Contrast with enterprise E2E matrix:** Reuses proven Cursor invoke harness (`tests/live/agents/cursor/agent.sh`, stream-json, Keychain auth, worktree isolation, composer-2.5). Does **not** load matrix ledger, matrix row outcome writers, or fixture branch locks unless explicitly testing matrix flows.

---

## When to use

| Use `/silver:agent-cursor` | Delegate inline or via host Task instead |
|----------------------------|------------------------------------------|
| Host is Claude/Codex and Cursor is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs Cursor-native SB hooks/skills/MCP in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`silver:feature`, orchestrator workers) |
| Cross-host handoff: "run this in Cursor while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Claude / Codex / Cursor parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | `cursor-agent` in target `--work-dir` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/silver:agent-cursor`** with a structured brief (below).
3. Parent runs `bash scripts/agent-cursor-delegate.sh` (or equivalent env setup) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→Cursor bridge; hook allows `agent-cursor-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to Cursor — supervise only.
3. Alternative: `silver-bullet invoke-skill silver-agent-cursor` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After Cursor completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-cursor/` (gitignored). Do not commit cursor-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow:

1. **FS-DELEGATE-BRIEF** — brief + `ownership_scope` path prefixes.
2. **`sb_orchestrator_seed_delegation_directive`** (`host=cursor`, `task_id`, `brief_path`, ownership JSON).
3. Spawn **AGENT-DELEGATE** native worker (`.silver-bullet/orchestrator-workers/AGENT-DELEGATE.md`).
4. Worker runs `agent-cursor-delegate.sh`; child loads **`silver-agent-worker`** (`composer-2.5` only on nested Tasks).
5. **FS-DELEGATE-MENTOR** — host verifies evidence vs brief.

**Degraded fallback:** parent direct wrapper requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or `SB OVERRIDE:` (not the happy path).

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what Cursor must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): /silver:plan → /silver:execute (Cursor picker syntax)

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-cursor/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `--work-dir` | Target repo root (e.g. `enterprise-grade-test-app-cursor`) | Fixture clone / worktree path |
| `SB_ROOT` | SB install path (for harness scripts) | SB repo checkout |
| `SB_AGENT_CURSOR_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot in Cursor child |
| `SB_LIVE_CURSOR_FORCE_HEADLESS` | `1` (delegate default) | `1` — force `cursor-agent` CLI, not IDE in-session |
| `SB_LIVE_CURSOR_IN_SESSION` | `0` (delegate default) | `1` only for IDE Composer bridge tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation. The delegate wrapper clears inherited matrix env.

### Harness env (Cursor learnings — E2E-091–100, §5b adapted)

| Env | Default | Purpose |
|-----|---------|---------|
| `CURSOR_AGENT_TIMEOUT` | 1800 | Hard timeout (seconds) — E2E-087/E2E-092 |
| `CURSOR_AGENT_MODEL` | `composer-2.5` | **Mandatory** — never `composer-2.5-fast` for subagent work |
| `CURSOR_MODEL` | `composer-2.5` | Alias for model picker consistency |
| `SB_AGENT_CURSOR_STREAM_JSON` | `1` (delegate) | stream-json log capture without matrix mode (E2E-093) |
| `SB_AGENT_CURSOR_LOG_FLOOR` | 2048 | Minimum log bytes for PASS evidence (§5b adapted) |
| `AGENT_CURSOR_QUOTA_RETRY_INTERVAL` | 60 | Rate-limit / quota backoff |
| `AGENT_CURSOR_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `RTK_DISABLED` | 1 | Set during delegate.sh for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | Cursor child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for exec subprocess |

### Auth policy (mandatory)

| Rule | Detail |
|------|--------|
| **Keychain login** | `cursor-agent login` — interactive Cursor auth stored in Keychain |
| **No API key** | Do **not** set `CURSOR_API_KEY` for delegation — bypasses Keychain check and breaks cert parity (§8) |
| **Preflight** | delegate.sh calls `agent_preflight` — fails fast if not logged in |

### Worktree / branch policy

| Rule | Detail |
|------|--------|
| **Isolated worktree** | Use dedicated worktree when shared clone is dirty on another branch ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)) |
| **Branch naming** | `feature/<task-slug>` or host-specific fixture branch — never stomp sibling host branches |
| **Honest baseline** | For product certification rounds, baseline SHA `09f8d1a` — not pre-seeded `8482e60` (§5a) |

Optional: extend timeout for heavy tasks — `CURSOR_AGENT_TIMEOUT=3600`.

---

## Step 3 — Invoke (parent)

```bash
export SB_ROOT=/path/to/silver-bullet/repo
export CURSOR_WORK_DIR=/path/to/target/project
export CURSOR_AGENT_MODEL=composer-2.5
unset CURSOR_API_KEY  # Keychain auth only

bash scripts/agent-cursor-delegate.sh \
  --work-dir "$CURSOR_WORK_DIR" \
  --brief-file .planning/agent-cursor/<task-id>/brief.md \
  --log .planning/agent-cursor/<task-id>/cursor-run.log
```

Inline prompt (small tasks):

```bash
bash scripts/agent-cursor-delegate.sh \
  --work-dir "$CURSOR_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-cursor/smoke/cursor-run.log
```

Use **absolute paths** for `--log` and `--brief-file` when invoking from a different CWD than SB_ROOT.

Cursor route prefix in prompts: use `/silver:*` (Cursor picker syntax).

Parent supervises by tailing the log file; stream-json lines decode to text deltas in the log.

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle (advisor-mentor without session persistence):

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm Cursor acknowledged task (log shows prompt submitted / first stream-json delta) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation — save to agentmemory |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Timeout, no post-submit output, 0 B log growth for >30 min | Re-brief with narrower scope; reduce acceptance criteria; retry once |
| **Quota / rate limit** | `429`, `rate limit`, `quota` in log | delegate.sh retries automatically; if exhausted, schedule resume after `AGENT_CURSOR_QUOTA_RETRY_INTERVAL` |
| **Auth** | `not logged in`, `authentication required` | Stop — user must run `cursor-agent login`; do not set `CURSOR_API_KEY` |
| **Model policy** | `composer-2.5-fast` in invoke args | Stop — re-invoke with `composer-2.5` only |
| **Harness** | `ERROR:` from delegate.sh or agent adapter | Fix SB harness; file issue if reproducible |
| **Product** | Cursor completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_CURSOR_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix stream-json path (E2E-093) |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_CURSOR_LOG_FLOOR` (default 2048 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-cursor/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos Cursor modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `model-policy` | `harness` | `product` | `log-floor`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, log bytes, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-cursor delegation outcomes"` after save + update.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no Cursor advantage).
- Task requires host-only tools (Codex TUI, browser MCP) without Cursor equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead (`cursor3-real-driver.sh`, `run-enterprise-e2e-matrix.sh`).

---

## References

- Harness: `scripts/agent-cursor-delegate.sh`
- Live adapter: `tests/live/agents/cursor/agent.sh`
- E2E adapter (matrix only): `scripts/enterprise-e2e/lib/adapters/cursor.sh`
- REAL drivers (matrix only): `.planning/enterprise-e2e/cursor3-real-driver.sh`, `cursor3-real-pipeline-driver.sh`
- Methodology: `docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md` §5a/§5b/§8
- Readiness audit: `docs/testing/CURSOR-METHODOLOGY-HARNESS-READINESS-AUDIT.md`
- Branch policy: `.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md`
