---
name: silver-agent-opencode
description: On-demand parent-supervised delegation of a single real task to OpenCode CLI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Cursor, Codex, or Claude parent) should supervise while OpenCode executes via opencode run in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--interaction-mode auto|interactive|non-interactive] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---

**Interaction modes:** `--interaction-mode auto|interactive|non-interactive` (default `auto`). Permission `--mode` remains `permissive|strict`. Spec: [`docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md`](../../docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md).

**Pinned NI fast path:** `--interaction-mode non-interactive` (or `--non-interactive` / `--use-print` / `--use-exec`) writes `mode.json` `{requested, classified:null, resolved:non-interactive, reason:[pin]}` and execs the native one-shot CLI with no classifier, D3/TUI probe, D4, recommended-tools preflight, quota-retry, or tail-idle watcher. Re-enable wrappers with `--quota-retry` / `AGENT_*_QUOTA_RETRY_MAX` and existing idle env. `auto` still runs the full resolver. Interactive is one native CLI or PTY (`pi` without `-p`; `cursor-agent` without `--print` when the CLI exists).


# /silver:agent-opencode — OpenCode CLI Subagent Delegation

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **OpenCode CLI** executes in the target project working directory via **`opencode run`** (primary non-interactive path).

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor). This skill activates **per task** and tears down when the task completes or escalates.

**Contrast with `/silver:agent-codex`, `/silver:agent-cursor`, `/silver:agent-claude`, and `/silver:agent-pi`:** Multi-host on-demand delegation siblings. Use **agent-opencode** when OpenCode CLI (`opencode run`) is the intended executor with MiMo V2.5 via opencode-go; use **agent-pi** for Pi CLI (`pi -p`); use **agent-claude** for Claude Code TUI; use **agent-codex** for Codex CLI; use **agent-cursor** for Cursor CLI.

**Contrast with enterprise E2E matrix:** Reuses proven OpenCode live adapter (`tests/live/agents/opencode/agent.sh`, `opencode run` with tail-idle completion, quota retry, model pin). Does **not** load matrix ledger, §5b product gates, fixture branch locks, or row outcome writers.

---

## When to use

| Use `/silver:agent-opencode` | Delegate inline or via host Task instead |
|------------------------------|------------------------------------------|
| Host is Cursor/Codex/Claude and OpenCode is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs OpenCode-native SB hooks/skills in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`silver:feature`, orchestrator workers) |
| Cross-host handoff: "run this in OpenCode while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Cursor / Codex / Claude parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | OpenCode CLI in `OPENCODE_WORK_DIR` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/silver:agent-opencode`** with a structured brief (below).
3. Parent runs `bash scripts/agent-opencode/invoke.sh` (preflight + env + delegate) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→OpenCode bridge; hook allows `agent-opencode/invoke.sh` with degraded fallback or `agent-opencode-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to OpenCode — supervise only.
3. Alternative: `silver-bullet invoke-skill silver-agent-opencode` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After OpenCode completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-opencode/` (gitignored). Do not commit opencode-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow instead of direct wrapper supervision:

1. Complete **FS-DELEGATE-BRIEF** (brief + `ownership_scope` path prefixes).
2. Call **`sb_orchestrator_seed_delegation_directive`** (`host=opencode`, `task_id`, `brief_path`, ownership JSON).
3. Spawn native worker **`.silver-bullet/orchestrator-workers/AGENT-DELEGATE.md`** (Task subagent).
4. Worker launches `agent-opencode-delegate.sh`; external agent loads **`silver-agent-worker`** contract.
5. Host runs **FS-DELEGATE-MENTOR** — verify evidence vs brief before user report.

**Degraded fallback only:** direct `agent-opencode-delegate.sh` from parent requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (emits `EV-DELEGATE-DEGRADED-FALLBACK`). Not the happy path.

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what OpenCode must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): /silver:plan → /silver:execute

## Model pin (mandatory — no drift)
- Provider: opencode-go
- Model: mimo-v2.5
- Run model: opencode-go/mimo-v2.5
- Do **not** override OPENCODE_MODEL / OPENCODE_MODEL_PROVIDER / OPENCODE_RUN_MODEL in brief or ephemeral homes — harness rejects drift.

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-opencode/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `OPENCODE_WORK_DIR` | Target repo root (e.g. `enterprise-grade-test-app`) | Fixture clone path |
| `SB_ROOT` | SB install path (for harness scripts) | SB repo checkout |
| `SB_AGENT_OPENCODE_FIXTURE` | `0` (default) | `1` — enables live-test guard patterns |
| `SB_AGENT_OPENCODE_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot in child |
| `SB_LIVE_OPENCODE_ISOLATION_ACTIVE` | `0` unless isolating config | `1` for hermetic live tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation.

### Model policy (MANDATORY)

MiMo V2.5 via **opencode-go** only. Harness, delegate wrapper, and live adapter pin via `agent_opencode_pin_mimo_model_env` — any override fails preflight.

| Env | Pinned value | Purpose |
|-----|--------------|---------|
| `OPENCODE_MODEL` | `mimo-v2.5` | Child model id |
| `OPENCODE_MODEL_PROVIDER` | `opencode-go` | Provider namespace |
| `OPENCODE_RUN_MODEL` | `opencode-go/mimo-v2.5` | `opencode run -m` argument |

Do **not** set alternate models in briefs, ephemeral config homes, or delegation prompts — no model drift in ephemeral homes.

### Harness env (reuse)

| Env | Default | Purpose |
|-----|---------|---------|
| `OPENCODE_RUN_TIMEOUT` | 900 | Hard run timeout (seconds) |
| `OPENCODE_RUN_TAIL_IDLE_TIMEOUT` | 45 | Tail-idle complete after activity |
| `AGENT_OPENCODE_QUOTA_RETRY_INTERVAL` | 60 | 429 / quota backoff |
| `AGENT_OPENCODE_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `RTK_DISABLED` | 1 | Set during delegate for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | OpenCode child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for subprocess |
| `SB_AGENT_OPENCODE_LOG_FLOOR` | 512 | Minimum log bytes for PASS evidence (§5b adapted) |
| `SB_LIVE_OPENCODE_USE_INTERACTIVE` | 0 (default) | Set via `--use-interactive` for TUI fallback |
| `OPENCODE_BIN` | auto-resolve | Native CLI path (`~/.opencode/bin/opencode`; not Desktop `.app`) |

Optional: `AGENT_OPENCODE_MONITOR_INTERVAL` (default 30) — parent `monitor.sh` poll interval (seconds).

### Auth policy

- **OpenCode CLI auth** via native install (`curl -fsSL https://opencode.ai/install | bash`).
- **No mid-delegation key rotation** — auth failures escalate to user.
- **No inherit-keys shortcuts** (E2E-110) — do not paste API keys into briefs; `agent-delegate-common.sh` rejects secret patterns.
- Delegate inherits caller auth (not `env -i` clean-env).

---

## Step 3 — Invoke (parent)

**Path policy:** `--log` and `--brief-file` may be repo-relative; `agent-opencode-delegate.sh` canonicalizes them to **absolute paths** before read/write (relative paths resolve from their parent directory, not `OPENCODE_WORK_DIR`). Prefer absolute paths in briefs and automation to avoid ambiguity.

**Preflight (mandatory):**

```bash
export SB_ROOT=/path/to/silver-bullet/repo
bash scripts/agent-opencode/preflight.sh --sb-root "$SB_ROOT"
```

**Launch (recommended path — `opencode run` primary):**

```bash
export OPENCODE_WORK_DIR=/path/to/target/project

bash scripts/agent-opencode/invoke.sh \
  --work-dir "$OPENCODE_WORK_DIR" \
  --brief-file .planning/agent-opencode/<task-id>/brief.md \
  --log .planning/agent-opencode/<task-id>/opencode-run.log
```

Inline prompt (small tasks):

```bash
bash scripts/agent-opencode/invoke.sh \
  --work-dir "$OPENCODE_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-opencode/smoke/opencode-run.log
```

**Parent monitor (channel timeline)** — run in a second terminal while OpenCode works:

```bash
bash scripts/agent-opencode/monitor.sh --log .planning/agent-opencode/<task-id>/opencode-run.log
```

Monitor emits checkpoint bullets: prompt submitted, byte growth, log-floor status, stall/auth/quota signals. Do **not** claim PASS on 0-byte or sub-floor logs.

**Interactive TUI fallback** when `opencode run` is insufficient (PTY supervision, banner blocks):

```bash
bash scripts/agent-opencode/invoke.sh --use-interactive --work-dir "$OPENCODE_WORK_DIR" --brief-file ...
```

Parent should prefer **`opencode run`** for automation; use `--use-interactive` only after a `stuck`/`harness` timeout or when operator supervision requires the OpenCode TUI.

Direct `scripts/agent-opencode-delegate.sh` remains for worker/orchestrator paths; production parents should use `invoke.sh`.

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle:

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria + model pin |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm OpenCode acknowledged task (log shows `prompt.submitted` / `opencode run`) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Idle timeout, no post-submit output | Re-brief with narrower scope; retry once; try `--use-interactive` |
| **Quota (429)** | `rate limit`, `429`, `token plan` in log | delegate.sh retries automatically; if exhausted, schedule resume |
| **Auth** | `auth`, `login`, `not logged in` | Stop — user must refresh OpenCode credentials; do not rotate keys in prompt |
| **Model policy** | `OPENCODE_MODEL must be mimo-v2.5` | Fix env — harness enforces pin; do not override in brief |
| **Harness** | `ERROR:` from adapter harness | Fix SB harness; file issue if reproducible |
| **Product** | OpenCode completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_OPENCODE_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix harness path |
| **0-token stall** | Banner splash, no post-submit tokens | Operator auth if banner blocks submit; E2E-081 submit-order awareness |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

### R9 harness learnings (production delegation)

| Learning | Delegation application |
|----------|------------------------|
| **E2E-081 submit order** | Enter-wake / interactive fallback must not starve route submit — parent verifies `prompt submitted` in log before checkpoint 2 |
| **E2E-110** | No inherit-keys shortcuts — brief secret scan enforced |
| **Stale locks** | Do not reuse `.e2e-live-test*.lock` from matrix; delegation clears matrix env |
| **SB-only plugins** | `preflight.sh` validates OpenCode install surface |
| **Channel timeline** | Parent runs `monitor.sh` bullets between checkpoints |
| **Model pin** | `agent_opencode_pin_mimo_model_env` in harness, delegate, and adapter — no drift across ephemeral homes |

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_OPENCODE_LOG_FLOOR` (default 512 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-opencode/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos OpenCode modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `model-policy` | `harness` | `product` | `log-floor` | `0-token`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-opencode delegation outcomes"` after save + update.

---

## Security (delegation boundary)

| Risk | Mitigation |
|------|------------|
| **Secrets in brief/log** | `agent-delegate-common.sh` rejects briefs with `api_key`/`sk-` patterns; logs redacted before persist |
| **Matrix env bleed** | `agent-opencode/env.sh` clears `SB_E2E_*` ledger/lock vars |
| **Model drift** | `agent_opencode_pin_mimo_model_env` rejects non-MiMo overrides in harness, delegate, adapter |
| **Credential rotation in prompt** | Forbidden — auth failures escalate to user |
| **SB-only plugin surface** | Preflight validates host install |
| **Desktop .app confusion** | Preflight rejects `OpenCode.app` — automation uses native CLI only |

Run `security` / SENTINEL lens on harness changes under `scripts/agent-opencode/` before merge. Delegation logs live under `.planning/agent-opencode/` (gitignored) — do not commit.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no OpenCode advantage).
- Task requires host-only tools without OpenCode equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead.

---

## References

- Sibling hosts: [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](../../docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md)
- Claude sibling: [`skills/silver-agent-claude/SKILL.md`](../silver-agent-claude/SKILL.md)
- Codex sibling: [`skills/silver-agent-codex/SKILL.md`](../silver-agent-codex/SKILL.md)
- Cursor sibling: [`skills/silver-agent-cursor/SKILL.md`](../silver-agent-cursor/SKILL.md)
- Pi sibling: [`skills/silver-agent-pi/SKILL.md`](../silver-agent-pi/SKILL.md)
- Harness: `scripts/agent-opencode/` (`invoke.sh`, `preflight.sh`, `monitor.sh`, `env.sh`), `scripts/agent-opencode-delegate.sh`
- Live adapter: `tests/live/agents/opencode/agent.sh`
- CLI lib: `scripts/lib/opencode-cli.sh` (`agent_opencode_pin_mimo_model_env`)
