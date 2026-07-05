---
name: "silver:agent-codex"
title: "Agent Codex"
description: On-demand parent-supervised delegation of a single real task to Codex TUI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Cursor, Claude, or Codex parent) should supervise while Codex CLI executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--checkpoint <n>]"
user-invocable: true
version: 0.2.0
---

# /silver:agent-codex — Codex TUI Subagent Delegation

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **Codex TUI** executes in the target project working directory.

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor). This skill activates **per task** and tears down when the task completes or escalates.

**Contrast with enterprise E2E matrix:** Reuses proven Codex invoke harness (`codex-interactive-invoke.py`, hook trust, idle/quiet timeouts, 429 retry). Does **not** load matrix ledger, §5b product gates, fixture branch locks, or row outcome writers.

---

## When to use

| Use `/silver:agent-codex` | Delegate inline or via host Task instead |
|---------------------------|------------------------------------------|
| Host is Cursor/Claude and Codex is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs Codex-native SB hooks/skills in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`silver:feature`, orchestrator workers) |
| Cross-host handoff: "run this in Codex while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Cursor / Claude / Codex parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | Codex TUI in `CODEX_WORK_DIR` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/silver:agent-codex`** with a structured brief (below).
3. Parent runs `bash scripts/agent-codex/invoke.sh` (preflight + env + delegate) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→Codex bridge; hook allows `agent-codex/invoke.sh` with degraded fallback or `agent-codex-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to Codex — supervise only.
3. Alternative: `silver-bullet invoke-skill silver-agent-codex` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After Codex completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-codex/` (gitignored). Do not commit codex-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow instead of direct wrapper supervision:

1. Complete **FS-DELEGATE-BRIEF** (brief + `ownership_scope` path prefixes).
2. Call **`sb_orchestrator_seed_delegation_directive`** (`host=codex`, `task_id`, `brief_path`, ownership JSON).
3. Spawn native worker **`.silver-bullet/orchestrator-workers/AGENT-DELEGATE.md`** (Task subagent).
4. Worker launches `agent-codex-delegate.sh`; external agent loads **`silver-agent-worker`** contract.
5. Host runs **FS-DELEGATE-MENTOR** — verify evidence vs brief before user report.

**Degraded fallback only:** direct `agent-codex-delegate.sh` from parent requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (emits `EV-DELEGATE-DEGRADED-FALLBACK`). Not the happy path.

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what Codex must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): $silver:plan → $silver:execute (Codex picker syntax)

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-codex/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `CODEX_WORK_DIR` | Target repo root (e.g. `enterprise-grade-test-app`) | Fixture clone path |
| `SB_ROOT` | SB install path (for harness scripts) | SB repo checkout |
| `SB_AGENT_CODEX_FIXTURE` | `0` (default) | `1` — enables live-test guard patterns |
| `SB_AGENT_CODEX_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot + orchestrator context in Codex child |
| `SB_AGENT_CODEX_SKIP_MCP` | `1` when lightweight | `0` — do not strip `[mcp_servers.*]` from ephemeral `CODEX_HOME` |
| `SB_LIVE_CODEX_ISOLATION_ACTIVE` | `0` unless isolating Codex home | `1` for hermetic live tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation.

### Harness env (reuse)

| Env | Default | Purpose |
|-----|---------|---------|
| `CODEX_INTERACTIVE_TIMEOUT` | 900 | Hard PTY timeout (seconds) |
| `CODEX_INTERACTIVE_QUIET_TIMEOUT` | 300 | Quiet-after-activity complete |
| `CODEX_INTERACTIVE_READY_TIMEOUT` | 20 (harness); **120** via delegate | Prompt acceptance |
| `SB_AGENT_CODEX_MODEL_READY_TIMEOUT` | 120 | Delegate override for `CODEX_INTERACTIVE_READY_TIMEOUT` when model/MCP boot is slow |
| `CODEX_INTERACTIVE_IDLE_TIMEOUT` | 1800 (harness); **3600** via delegate | Idle watchdog |
| `AGENT_CODEX_QUOTA_RETRY_INTERVAL` | 60 | 429 / quota backoff |
| `AGENT_CODEX_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `CODEX_AUTO_TRUST_HOOKS` | 1 | Auto-accept hook trust when isolated |
| `CODEX_BYPASS_HOOK_TRUST` | 1 | Bypass hook trust prompt when pre-seeded |
| `RTK_DISABLED` | 1 | Set during delegate.sh for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | Codex child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for exec/PTY subprocess |
| `SB_AGENT_CODEX_LOG_FLOOR` | 512 | Minimum log bytes for PASS evidence (§5b adapted) |
| `AGENT_CODEX_MONITOR_INTERVAL` | 30 | Parent `monitor.sh` poll interval (seconds) |
| `CODEX_EXEC_TAIL_IDLE_TIMEOUT` | 45 | Exec-mode tail quiet-after-work |

Optional: `CODEX_MODEL`, `CODEX_MODEL_PROVIDER`, `CODEX_REASONING_EFFORT`.

---

## Step 3 — Invoke (parent)

**Path policy:** `--log` and `--brief-file` may be repo-relative; `agent-codex-delegate.sh` canonicalizes them to **absolute paths** before read/write (relative paths resolve from their parent directory, not `CODEX_WORK_DIR`). Prefer absolute paths in briefs and automation to avoid ambiguity.

**Preflight (mandatory):**

```bash
export SB_ROOT=/path/to/silver-bullet/repo
bash scripts/agent-codex/preflight.sh --sb-root "$SB_ROOT"
```

**Launch (recommended path):**

```bash
export CODEX_WORK_DIR=/path/to/target/project

bash scripts/agent-codex/invoke.sh \
  --work-dir "$CODEX_WORK_DIR" \
  --brief-file .planning/agent-codex/<task-id>/brief.md \
  --log .planning/agent-codex/<task-id>/codex-run.log
```

Inline prompt (small tasks):

```bash
bash scripts/agent-codex/invoke.sh \
  --work-dir "$CODEX_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-codex/smoke/codex-run.log
```

**Parent monitor (channel timeline)** — run in a second terminal while Codex works:

```bash
bash scripts/agent-codex/monitor.sh --log .planning/agent-codex/<task-id>/codex-run.log
```

Monitor emits checkpoint bullets: prompt submitted, byte growth, log-floor status, stall/auth/quota signals. Do **not** claim PASS on 0-byte or sub-floor logs.

**Headless fallback** when PTY TUI stalls (model loading, no quiet-complete):

```bash
bash scripts/agent-codex/invoke.sh --use-exec --work-dir "$CODEX_WORK_DIR" --brief-file ...
```

Parent should prefer interactive TUI for supervision; use `--use-exec` only after a `stuck`/`harness` timeout or when automation requires non-PTY.

Direct `scripts/agent-codex-delegate.sh` remains for worker/orchestrator paths; production parents should use `invoke.sh`.

Codex route prefix in prompts: use `$silver:*` (Codex picker), not `/silver:*`.

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle:

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm Codex acknowledged task (log shows prompt submitted) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Idle timeout, no post-submit output, repeated spinner | Re-brief with narrower scope; reduce acceptance criteria; retry once |
| **Quota (429)** | `rate limit`, `429`, `token plan` in log | delegate.sh retries automatically; if exhausted, schedule resume after `AGENT_CODEX_QUOTA_RETRY_INTERVAL` |
| **Auth** | `auth`, `login`, `api key` errors | Stop — user must refresh Codex credentials; do not rotate keys in prompt |
| **Hook trust** | `hooks need review`, trust prompt surfaced | Run `bash scripts/install-codex.sh --hook-trust-seed-only` from `SB_ROOT`; retry |
| **Harness** | `ERROR:` from `codex-interactive-invoke.py` | Fix SB harness; file issue if reproducible |
| **Product** | Codex completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_CODEX_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix harness path; do not claim PASS on 0-token / empty log |
| **0-token stall** | MCP banner, mode banner, no post-submit tokens | Harness Enter-wake (E2E-081); strip MCP in lightweight `CODEX_HOME`; operator auth if banner blocks submit |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

### R9 harness learnings (production delegation)

| Learning | Delegation application |
|----------|------------------------|
| **E2E-081 submit order** | Enter-wake for 0-token banner must not starve `$silver:*` route submit — harness sends wake then paste; parent verifies `prompt submitted` in log before checkpoint 2 |
| **Stale locks** | Do not reuse `.e2e-live-test*.lock` from matrix; delegation clears matrix env; use per-task log under `.planning/agent-codex/` only |
| **SB-only plugins** | `preflight.sh` validates Codex install surface; child uses SB marketplace package — no third-party skill pollution in ephemeral `CODEX_HOME` |
| **Hook preflight** | `install-codex.sh --hook-trust-seed-only` before invoke; `CODEX_BYPASS_HOOK_TRUST=1` when pre-seeded |
| **No false completion on 0-token** | PASS requires log floor + product evidence; monitor warns below floor; outcome FAIL if delegate exit 0 but acceptance unmet |
| **Channel timeline** | Parent runs `monitor.sh` bullets between checkpoints — not matrix batch PID polling |

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_CODEX_LOG_FLOOR` (default 512 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-codex/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos Codex modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `hook-trust` | `harness` | `product` | `log-floor` | `0-token`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-codex delegation outcomes"` after save + update.

---

## Security (delegation boundary)

| Risk | Mitigation |
|------|------------|
| **Secrets in brief/log** | `agent-delegate-common.sh` rejects briefs with `api_key`/`sk-` patterns; logs redacted before persist |
| **Matrix env bleed** | `agent-codex/env.sh` clears `SB_E2E_*` ledger/lock vars — never inherit matrix certification state |
| **Hook trust bypass** | `CODEX_BYPASS_HOOK_TRUST` only when `install-codex.sh --hook-trust-seed-only` ran; parent audits trust state on hook-trust failures |
| **Ephemeral CODEX_HOME** | Lightweight mode strips `[mcp_servers.*]` to reduce MCP auth attack surface; destroyed after task |
| **Credential rotation in prompt** | Forbidden — auth failures escalate to user; never paste API keys into Codex prompt |
| **SB-only plugin surface** | Preflight validates host install; child must not load unvetted marketplace skills into delegation session |

Run `security` / SENTINEL lens on harness changes under `scripts/agent-codex/` before merge. Delegation logs live under `.planning/agent-codex/` (gitignored) — do not commit.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no Codex advantage).
- Task requires host-only tools (Cursor Task workers, browser MCP) without Codex equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead.

---

## References

- Sibling hosts: [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](../../docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md) — meta-prompt to build `/silver:agent-<host>` on other hosts
- Harness: `scripts/agent-codex/` (`invoke.sh`, `preflight.sh`, `monitor.sh`, `env.sh`), `scripts/codex-interactive-invoke.py`, `scripts/agent-codex-delegate.sh`
- Live adapter: `tests/live/agents/codex/agent.sh`
- E2E adapter (matrix only): `scripts/enterprise-e2e/lib/adapters/codex.sh`
- Protocol (matrix): `.planning/enterprise-e2e/CODEX-TUI-PROTOCOL.md`
- Readiness audit: `docs/testing/CODEX-METHODOLOGY-HARNESS-READINESS-AUDIT.md`
