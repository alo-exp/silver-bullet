---
name: "silver:agent-claude"
title: "Agent Claude"
description: On-demand parent-supervised delegation of a single real task to Claude TUI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Cursor, Codex, or Claude parent) should supervise while Claude Code executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---

# /silver:agent-claude — Claude TUI Subagent Delegation

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **Claude TUI** executes in the target project working directory.

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor). This skill activates **per task** and tears down when the task completes or escalates.

**Contrast with `/silver:agent-codex` and `/silver:agent-cursor`:** Tri-host on-demand delegation siblings. Use **agent-claude** when Claude Code TUI is the intended executor; use **agent-codex** for Codex CLI; use **agent-cursor** for Cursor CLI.

**Contrast with enterprise E2E matrix:** Reuses proven Claude invoke harness (`claude-interactive-invoke.expect`, OAuth auth, idle/quiet timeouts, 429 retry, isolated `CLAUDE_CONFIG_DIR`). Does **not** load matrix ledger, §5b product gates, fixture branch locks, or row outcome writers.

---

## When to use

| Use `/silver:agent-claude` | Delegate inline or via host Task instead |
|----------------------------|------------------------------------------|
| Host is Cursor/Codex and Claude is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs Claude-native SB hooks/skills in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`silver:feature`, orchestrator workers) |
| Cross-host handoff: "run this in Claude while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Cursor / Codex / Claude parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | Claude TUI in `CLAUDE_WORK_DIR` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/silver:agent-claude`** with a structured brief (below).
3. Parent runs `bash scripts/agent-claude/invoke.sh` (preflight + env + delegate) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→Claude bridge; hook allows `agent-claude/invoke.sh` with degraded fallback or `agent-claude-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to Claude — supervise only.
3. Alternative: `silver-bullet invoke-skill silver-agent-claude` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After Claude completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-claude/` (gitignored). Do not commit claude-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow instead of direct wrapper supervision:

1. Complete **FS-DELEGATE-BRIEF** (brief + `ownership_scope` path prefixes).
2. Call **`sb_orchestrator_seed_delegation_directive`** (`host=claude`, `task_id`, `brief_path`, ownership JSON).
3. Spawn native worker **`.silver-bullet/orchestrator-workers/AGENT-DELEGATE.md`** (Task subagent).
4. Worker launches `agent-claude-delegate.sh`; external agent loads **`silver-agent-worker`** contract.
5. Host runs **FS-DELEGATE-MENTOR** — verify evidence vs brief before user report.

**Degraded fallback only:** direct `agent-claude-delegate.sh` from parent requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (emits `EV-DELEGATE-DEGRADED-FALLBACK`). Not the happy path.

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what Claude must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): /silver:plan → /silver:execute (Claude picker syntax)

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-claude/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `CLAUDE_WORK_DIR` | Target repo root (e.g. `enterprise-grade-test-app`) | Fixture clone path |
| `SB_ROOT` | SB install path (for harness scripts) | SB repo checkout |
| `SB_AGENT_CLAUDE_FIXTURE` | `0` (default) | `1` — enables live-test guard patterns |
| `SB_AGENT_CLAUDE_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot in child |
| `SB_LIVE_CLAUDE_ISOLATION_ACTIVE` | `0` unless isolating config | `1` for hermetic live tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation.

### Harness env (reuse)

| Env | Default | Purpose |
|-----|---------|---------|
| `CLAUDE_INTERACTIVE_TIMEOUT` | 900 | Hard PTY timeout (seconds) |
| `CLAUDE_INTERACTIVE_QUIET_TIMEOUT` | 120 | Quiet-after-activity complete |
| `CLAUDE_INTERACTIVE_READY_TIMEOUT` | 20 (harness); **120** via delegate | Prompt acceptance |
| `SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT` | 120 | Delegate override for ready timeout when model boot is slow |
| `CLAUDE_INTERACTIVE_IDLE_TIMEOUT` | 1800 (harness); **3600** via delegate | Idle watchdog |
| `AGENT_CLAUDE_QUOTA_RETRY_INTERVAL` | 60 | 429 / quota backoff |
| `AGENT_CLAUDE_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `CLAUDE_USE_INTERACTIVE` | 1 (delegate) | Force expect TUI path |
| `RTK_DISABLED` | 1 | Set during delegate for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | Claude child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for exec/PTY subprocess |
| `SB_AGENT_CLAUDE_LOG_FLOOR` | 512 | Minimum log bytes for PASS evidence (§5b adapted) |
| `AGENT_CLAUDE_MONITOR_INTERVAL` | 30 | Parent `monitor.sh` poll interval (seconds) |

Optional: `CLAUDE_MODEL` (default `sonnet`), `CLAUDE_EFFORT` (default `low`).

### Auth policy

- **OAuth / Keychain** via `claude auth login` — preflight checks auth status.
- **No mid-delegation key rotation** — auth failures escalate to user.
- **No inherit-keys shortcuts** (E2E-110) — do not paste API keys into briefs; `agent-delegate-common.sh` rejects secret patterns.
- Proxy/MiniMax hosts: document Claude host settings env (under isolated `CLAUDE_CONFIG_DIR`); delegate inherits caller auth (not `env -i` clean-env).

---

## Step 3 — Invoke (parent)

**Path policy:** `--log` and `--brief-file` may be repo-relative; `agent-claude-delegate.sh` canonicalizes them to **absolute paths** before read/write (relative paths resolve from their parent directory, not `CLAUDE_WORK_DIR`). Prefer absolute paths in briefs and automation to avoid ambiguity.

**Preflight (mandatory):**

```bash
export SB_ROOT=/path/to/silver-bullet/repo
bash scripts/agent-claude/preflight.sh --sb-root "$SB_ROOT"
```

**Launch (recommended path):**

```bash
export CLAUDE_WORK_DIR=/path/to/target/project

bash scripts/agent-claude/invoke.sh \
  --work-dir "$CLAUDE_WORK_DIR" \
  --brief-file .planning/agent-claude/<task-id>/brief.md \
  --log .planning/agent-claude/<task-id>/claude-run.log
```

Inline prompt (small tasks):

```bash
bash scripts/agent-claude/invoke.sh \
  --work-dir "$CLAUDE_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-claude/smoke/claude-run.log
```

**Parent monitor (channel timeline)** — run in a second terminal while Claude works:

```bash
bash scripts/agent-claude/monitor.sh --log .planning/agent-claude/<task-id>/claude-run.log
```

Monitor emits checkpoint bullets: prompt submitted, byte growth, log-floor status, stall/auth/quota signals. Do **not** claim PASS on 0-byte or sub-floor logs.

**Print fallback** when expect/PTY unavailable:

```bash
bash scripts/agent-claude/invoke.sh --use-print --work-dir "$CLAUDE_WORK_DIR" --brief-file ...
```

Parent should prefer interactive TUI for supervision; use `--use-print` only after a `stuck`/`harness` timeout or when automation requires non-PTY.

Direct `scripts/agent-claude-delegate.sh` remains for worker/orchestrator paths; production parents should use `invoke.sh`.

Claude route prefix in prompts: use `/silver:*` or `[$silver]` (Claude picker), not `$silver:*` (Codex).

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle:

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm Claude acknowledged task (log shows prompt submitted) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Idle timeout, no post-submit output, `Queued follow-up` | Re-brief with narrower scope; Enter-wake (E2E-081); retry once |
| **Quota (429)** | `rate limit`, `429`, `token plan` in log | delegate.sh retries automatically; if exhausted, schedule resume |
| **Auth** | `auth`, `login`, `not logged in` | Stop — user must refresh Claude credentials; do not rotate keys in prompt |
| **Harness** | `ERROR:` from expect harness | Fix SB harness; file issue if reproducible |
| **Product** | Claude completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_CLAUDE_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix harness path |
| **0-token stall** | Splash banner, mode banner, no post-submit tokens | Harness Enter-wake (E2E-081); operator auth if banner blocks submit |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

### R9 harness learnings (production delegation)

| Learning | Delegation application |
|----------|------------------------|
| **E2E-081 submit order** | Enter-wake for 0-token banner must not starve `/silver:*` route submit — parent verifies `prompt submitted` in log before checkpoint 2 |
| **E2E-105** | Fresh `CLAUDE_CONFIG_DIR` + `$HOME/.codex/.silver-bullet` per delegation wave in lightweight mode |
| **E2E-110** | No inherit-keys shortcuts — OAuth auth policy documented; brief secret scan enforced |
| **Stale locks** | Do not reuse `.e2e-live-test*.lock` from matrix; delegation clears matrix env |
| **SB-only plugins** | `preflight.sh` validates Claude install surface |
| **Channel timeline** | Parent runs `monitor.sh` bullets between checkpoints |

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_CLAUDE_LOG_FLOOR` (default 512 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-claude/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos Claude modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `harness` | `product` | `log-floor` | `0-token`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-claude delegation outcomes"` after save + update.

---

## Security (delegation boundary)

| Risk | Mitigation |
|------|------------|
| **Secrets in brief/log** | `agent-delegate-common.sh` rejects briefs with `api_key`/`sk-` patterns; logs redacted before persist |
| **Matrix env bleed** | `agent-claude/env.sh` clears `SB_E2E_*` ledger/lock vars |
| **Ephemeral CLAUDE_CONFIG_DIR** | Lightweight mode isolates config per wave; destroyed after task |
| **Credential rotation in prompt** | Forbidden — auth failures escalate to user |
| **SB-only plugin surface** | Preflight validates host install |

Run `security` / SENTINEL lens on harness changes under `scripts/agent-claude/` before merge. Delegation logs live under `.planning/agent-claude/` (gitignored) — do not commit.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no Claude advantage).
- Task requires host-only tools without Claude equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead.

---

## References

- Sibling hosts: [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](../../docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md)
- Cursor sibling: [`skills/silver-agent-cursor/SKILL.md`](../silver-agent-cursor/SKILL.md)
- Harness: `scripts/agent-claude/` (`invoke.sh`, `preflight.sh`, `monitor.sh`, `env.sh`), `scripts/claude-interactive-invoke.expect`, `scripts/agent-claude-delegate.sh`
- Live adapter: `tests/live/agents/claude/agent.sh`
- Auth: `scripts/lib/claude-matrix-auth.sh`
- E2E adapter (matrix only): `scripts/enterprise-e2e/lib/adapters/claude.sh`
- Protocol (matrix): `.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md`
