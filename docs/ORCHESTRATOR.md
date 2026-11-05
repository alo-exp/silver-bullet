# Silver Bullet Orchestrator Contract

**Status:** Parent-only orchestration (2026-06-14)

Silver Bullet's orchestrator sequences lifecycle work through **directives**, **Task workers**, and **hooks**. The parent session NEVER implements directly — cooperative single-agent mode is removed.

## Execution model

| Role | Session | May implement? | Tools |
|------|---------|----------------|-------|
| **Parent** | Main agent / `/sb` | **No** | Task, Read, Grep, Glob; Skill: `silver` / `silver-orchestrator` only |
| **Worker** | Task subagent per atomic flow | **Yes** (after assigned skill) | Full tool surface per flow contract; **invoke** (not merely read) the assigned skill |

On tier-2 hosts the parent **spawns Task workers**; workers **invoke** flow-atom skills so hooks record state.

**Tier 0–1 hosts** (no Task/subagent support or hooks not merged): invoke the same skill sequence **directly** in a single session — read `docs/RUNTIME-COMPATIBILITY.md` §Tier 0–1 playbook. Parent-only directive blocks apply only when tier ≥ 2 and `orchestrator_mode` is `parent`.

Config: `"orchestrator_mode": "parent"` (only allowed value; default in template).

## State surfaces

| File | Scope | Purpose |
|------|-------|---------|
| `${SB_RUNTIME_STATE_DIR}/orchestrator.json` | Session/branch | Intent, `flow_queue`, `current_flow`, `workflow_id` |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json` | Session/branch | **Mandatory next skill** + `next_worker_template` when `blocking: true` |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt` | Session | Latest user intent (first line) |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-worker-active.json` | Session | Evidence record of the latest delegation (`spawned_at`, skill, template). **Never used to classify a session** — see [Worker identity](#worker-identity) |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-events.jsonl` | Session | Durable orchestration event log (dispatch, join, advance, stop_block, retry). Bounded: past 1 MiB (`SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES`) it is cut back to the newest 2000 lines (`SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES`) |
| `${SB_RUNTIME_STATE_DIR}/orchestrator.lock/` | Session | Short-lived mkdir lock around every `orchestrator.json` read-modify-write (stale after 1 minute, 5 s wait, then proceeds unlocked) |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-stop-blocks.json` | Session | Parent Stop-block counter (see [Stop release](#stop-release)) |
| `${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved` | Session | Human sign-off marker when enterprise policy blocks production delivery |
| `.scheduler.batch_dispatch` (in `orchestrator.json`) | Session | Active parallel/sequential batch handoffs + join status |
| `.silver-bullet/orchestrator-workers/*.md` | Project | Worker prompt templates (stamped by `sb:init`) |
| `.planning/orchestrator-composition-log.jsonl` | Committed | Autonomous composition audit |
| `.planning/orchestrator-override-log.jsonl` | Committed | User `SB OVERRIDE:` audit trail |

## Directive schema (`orchestrator-directive.json`)

```json
{
  "next_skill": "silver-quality-gates",
  "next_worker_template": "QUALITY-GATE",
  "args": "optional intent snippet",
  "reason": "human-readable why",
  "blocking": true,
  "updated_at": "2026-06-14T12:00:00Z"
}
```

When the catalog scheduler groups multiple dependency-ready atoms into one batch, `batch_dispatch` is added (shell hooks cannot spawn host Task workers — the parent reads this and spawns workers):

```json
{
  "batch_dispatch": {
    "batch_index": 0,
    "dispatch_mode": "parallel",
    "host_parallel_capable": true,
    "status": "pending_dispatch",
    "handoffs": [
      {
        "atomic_flow_id": "AF-ORIENT",
        "next_skill": "silver-context",
        "next_worker_template": "ORIENT",
        "dispatch_status": "pending",
        "join_status": "pending"
      }
    ]
  }
}
```

Hosts without multitask/subagent support (`SB_ORCHESTRATOR_PARALLEL_DISPATCH=0` or tier &lt; 2) get `dispatch_mode: "sequential"` — only the first pending handoff is surfaced via `next_skill` while join gates still apply.

**Parent Task spawn (required on tier ≥ 2):** Shell hooks **cannot** invoke the host `Task` tool. When `blocking: true` and `batch_dispatch` is present, the **parent session must spawn Task workers** (one per pending handoff on parallel-capable hosts). `stop-check.sh` blocks parent Stop until handoffs are dispatched and joined. Reading the directive alone does not satisfy the contract — only recorded worker skill invocation + join state advance the queue.

**Batch join gate:** While the batch that contained the completed atom still has unjoined handoffs, `sb_orchestrator_advance_on_atom` records `last_completed` but **does not** advance `current_flow` or overwrite the batch directive. The decision comes from the join itself (`SB_SCHEDULER_JOIN_RESULT`: `batch-pending`, `batch-complete`, `no-match`, `no-batch`), not from asking afterwards whether any batch has pending joins: the join that completes a batch dispatches the next one immediately. When a batch completes, `current_flow` moves to the queue token after the last finisher and the next batch's directive (with its handoff metadata) is kept. A parallel sibling that finishes out of order (its queue position is behind `last_completed_index`) still joins; only the join that completes the batch moves the queue. Sequential behavior is unchanged when scheduler state is absent. Handoff join matching resolves skills through `migration_map` (`runtime_queue_tokens`, `skill_to_entity`, `gsd_alias_to_entity`), `FLOW-*` normalization, and slug fallbacks (`hooks/lib/orchestrator-skill-atom.sh`).

**Handoff skill names:** each handoff's `next_skill` is `sb_orchestrator_flow_to_skill` applied to the `flow_queue` token the atom came from (the plan carries `.scheduler.batch_tokens` beside `.scheduler.batches`), so the directive, the guard and `stop-check` all name an installed skill. There is no second mapping.

**Re-running a finished atom:** a completion is matched forward from `last_completed_index + 1`. A completion that can only match a *later twin* of an atom that already ran (`silver-quality-gates` again versus `FLOW-QUALITY-GATE-PRESHIP`) is a re-run and is ignored; it never skips review, verify and secure.

**Planner:** atoms join the dependency set only when their batch closes. An atom whose `depends_on_atoms` entry sits in the open batch is placed in a later batch (decision `depends_on_atoms in the same batch`), and a serial atom closes the open batch before it. The shipped catalog gives every atom the same two placeholder mutation scopes (`declared artifacts`, `scoped repository paths`), so every pair conflicts and the shipped queues plan to one atom per batch. Parallel batches need atoms with distinct, real `mutation_scopes`.

**Delivery floor in queues:** a queue that reaches `silver-ship` through the review triad also records the `required_deploy` skills no atom stands for: `silver-triage` after `silver-review-triage`, `verify-tests` after `silver-verify` and `tdd` before `silver-execute` (`sb_orchestrator_apply_deploy_floor`). The configured list is authoritative: a project that drops one from `required_deploy` does not get it queued, and the devops list has no `tdd`. Following the queue exactly leaves `gh pr create` unblocked for workflow skills. `templates/workflows/*.md` (and the identical `docs/workflows/*.md`) name every `required_deploy` skill; `tests/docs/test-workflow-required-deploy.sh` checks it.

**Planning floor in queues:** `sb_orchestrator_queue_for_composer` inserts the skills of the project's `required_planning` list (`required_planning_devops` for `sb:devops`; the shipped default when the project has none) that the queue lacks, right before `silver-plan` (or `silver-execute` when there is no plan step). `dev-cycle-check` and `completion-audit` refuse source edits and commits until those skills are recorded, so a worker that follows the queue is never stopped by them. `sb:bugfix` runs `sb:debug` first, then quality-gates, context and plan.

## Parent loop

```
User intent → /sb or silver-orchestrator
  → composer spec seeds orchestrator.json + workflows.sh
  → directive: next_skill + next_worker_template
  → parent **must spawn Task** with `.silver-bullet/orchestrator-workers/<TEMPLATE>.md` (hooks cannot spawn)
  → worker invokes next_skill → implements flow
  → flow-advance writes next directive
  → repeat until queue empty
```

## Worker contract

Each worker template (`templates/orchestrator-workers/`) includes:

- Flow contract reference (`docs/composable-flows-contracts.md`)
- Mandatory skill invocation
- Acceptance criteria and handoff artifacts

Do **not** put `SB_ORCHESTRATOR_WORKER=1` in a Task prompt: a process cannot change its parent's environment, and an agent that exports it in its own commands changes nothing (hooks read their own environment). The host identifies workers; see below.

### Worker identity

Whether a hook call comes from a worker is decided **per call** from the hook payload: Claude Code adds `agent_id` (and `agent_type`) to every hook call made inside a subagent, and the main session's payloads never carry it (`sb_orchestrator_is_worker_session`, which reads the payload from its argument or `SB_ORCH_HOOK_INPUT`). Only top-level payload fields count; text inside `tool_input` proves nothing. A missing id never means worker. Two environment switches stay for hosts and tests: `SB_ORCHESTRATOR_WORKER=1` (worker) and `SB_ORCHESTRATOR_PARENT=0|1` (explicit; `1` wins over a payload id). There is no global "a worker was spawned" marker: it could not tell the parent from a worker, two parallel workers from one, or a spawn that never started. A `Stop` event is always the parent's (workers end with `SubagentStop`), so the Stop-time site gates (`live-publish-evidence-gate`, `v-loop-rollup-gate`) never skip on a worker signal.

**Parent-mode enforcement needs host worker identity; Claude has it, Codex pending.** A host that does not identify workers in hook payloads (Codex for now; any `SILVER_BULLET_RUNTIME` other than `claude`) cannot tell a worker's edit from the parent's, so there parent mode is INACTIVE: `sb_orchestrator_is_parent_session` is false, the directive guard does not deny, and the Stop queue block does not apply (the planning floor and every other gate still do). `SB_ORCHESTRATOR_PARENT=1` forces it on (tests, hosts whose adapter exports worker identity as `SB_ORCHESTRATOR_WORKER=1`).

### Parent Bash

The parent may run Bash only when the shared shell classifier (`hooks/lib/shell-analysis.sh`) says the call is (1) **strictly read-only** (`read_only`, the strict allowlist: `git status`, `ls`, `cat`, `graphify query`, pipes of such commands; test runners are *not* read-only), or (2) **one** command, with no redirect or other write, whose program is a sanctioned parent tool: `silver-bullet invoke-skill silver|silver-orchestrator|silver-agent-*` (also behind `env`, `NAME=value`, `bash -c`, `bash <script>`), `scripts/resolve-instruction-ledger.sh [list|done|deferred|help]`, or, only with `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1`, the agent delegate scripts. Chains, pipes into a shell, command substitutions and a command that merely *mentions* one of those names are denied. Assignment or `env` prefixes on a sanctioned command (`BASH_ENV=`, `PATH=`, `LD_PRELOAD=`, `env -i`, also inside a `sh -c` payload) are denied, and `bash <file>` is accepted for the adapter only when the file is this plugin's own `scripts/silver-bullet`. If the classifier itself is unavailable (python3 missing or crashed) the call is denied with a message saying how to proceed.

Event-log tail/resume and saga helpers were removed (nothing called them); the log is evidence for the enterprise scorers.

## Enterprise policy runtime (Phase B+D)

When `enterprise_policy.active_profile` is set in `.silver-bullet.json`:

| Field | Runtime consumer |
|-------|------------------|
| `clarify_auto` | `session-start` injects `/sb:clarify --auto` hint |
| `evidence_schema_strict` | `completion-audit` delivery gate strictness (with `hooks.evidence_schema.strict`) |
| `production_deploy_requires_human` | Blocks `gh pr create`, `gh release create`, `deploy` unless `${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved` exists |
| `non_production_deploy_autonomy` | Allows staging/non-prod deploy commands when profile permits (e.g. `internal_dogfood`) |

## Durable event log

| API (`hooks/lib/orchestrator-event-log.sh`) | Purpose |
|--------------------------------------------|---------|
| `sb_orchestrator_event_record_*` | Append dispatch/join/advance/stop_block/retry events (refuses a symlinked log; bounded as described above) |

Writers of `orchestrator.json` and the directive go through `hooks/lib/orchestrator-io.sh`: `sb_orchestrator_atomic_write` (unique temp file in the same directory, rename, refuses symlinks and directories) and `sb_orchestrator_with_lock` (re-entrant mkdir lock around read-modify-write), so two workers finishing together no longer lose a join.

## Enforcement (tier ≥ 2)

| Hook | Parent behavior | Worker behavior |
|------|-----------------|-----------------|
| `orchestrator-directive-guard.sh` | Blocks Edit/Write and Bash outside the [parent Bash](#parent-bash) policy; allows Task; blocks direct flow Skill | Blocks Edit/Write until `next_skill` recorded; Bash is allowed without a skill record (delivery ops) |
| `stop-check.sh` | Blocks Stop while `current_flow` pending **or** scheduler batch dispatch/join pending (blocked join gates, undispatched handoffs, failed step V-loops); released after repeated blocks with no progress | A worker's `SubagentStop` is skipped and touches no shared state |
| `prompt-reminder.sh` | Injects directive + parent mode banner | Injects directive |
| `session-start` | Parent mode context | Worker when `SB_ORCHESTRATOR_WORKER=1` |

### Stop release

A parent Stop that is blocked while nothing in `orchestrator.json` changes would trap the session. `sb_orchestrator_stop_block_released` counts blocks by the file's checksum and releases the Stop after `SB_ORCHESTRATOR_STOP_BLOCK_LIMIT` (default 5) blocks with no change; any queue or scheduler update restarts the count. The release skips only the two orchestrator blocks: the planning floor, the stall block and every later check still run on every Stop, and a `stop_release` event is logged. `SB OVERRIDE: <reason>` (honoured on the user's prompt by `outcomes-check`, which logs it to `.planning/orchestrator-override-log.jsonl`) clears the pending directive; a PreToolUse payload's `prompt` field is ignored.

### Cursor / tier 0–1

Guidance only — `templates/cursor-rules/silver-orchestrator.mdc` + directive injection. Tier 2+ required for mechanical parent blocks.

## Host modes — Plan & Debug (E2E-013)

Silver Bullet hooks do **not** read host mode from stdin today. Operators and agents should treat modes as follows:

| Host mode | Parent may | SB enforcement |
|-----------|------------|----------------|
| **Agent (default)** | Spawn Task workers; read-only Bash in parent | Full PreToolUse/Stop stack |
| **Plan** (`SwitchMode` → plan) | Read/Grep/Glob + Task PLAN worker; **no** direct Edit/Write in parent | `orchestrator-directive-guard` still blocks parent writes; route planning via workers |
| **Debug** | Route to `sb:debug` / `sb:forensics` queue — not freestyle Bash | Stop/PreToolUse still fire; use `SB OVERRIDE:` only for audited bypass |
| **Ask** | Read-only tools | Aligns with parent read-only subset |

**Enterprise E2E:** Matrix rows run in autonomous Agent mode. Do not switch to Plan/Debug mid-row — outcome scorers expect worker completion markers.

**Future:** SessionStart may inject `SB PLAN MODE` context when hosts expose mode hints reliably.

## SubagentStop semantics

- **Worker SubagentStop:** does not block (parent continues) and does not touch shared state, because other workers may still be running.
- **Parent Stop:** Blocked while orchestrator queue has pending `current_flow` **or** scheduler runtime work remains (pending batch handoffs, dispatched-but-unjoined workers, blocked join gates, failing step V-loops) — parent must spawn next Task worker(s) per `orchestrator-directive.json` `batch_dispatch`.

### Skill recording from workers

Workers must invoke assigned flow skills through the host's SB-recognized channel (`Skill` tool, `scripts/silver-bullet invoke-skill`, or equivalent) so `PostToolUse/Skill` → `record-skill.sh` appends markers to `${SB_RUNTIME_STATE_DIR}/state`. Parent Task spawns do not auto-record skills — the worker invocation does. If delivery gates report missing skills after a worker completed, verify the worker used a recorded channel rather than reading the skill file inline.

## Migration

Existing projects:

```bash
bash scripts/sb-migrate-orchestrator-parent.sh [project-root]
```

Sets `orchestrator_mode: parent`, copies worker templates and Cursor rule.

## Related docs

- `docs/RUNTIME-COMPATIBILITY.md` — capability tiers; Cursor tier 2 requires Task/subagent support
- `docs/composable-flows-contracts.md` — atomic flow catalog
- `skills/silver-orchestrator/SKILL.md` — parent skill contract
