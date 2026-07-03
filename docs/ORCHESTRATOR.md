# Silver Bullet Orchestrator Contract

**Status:** Parent-only orchestration (2026-06-14)

Silver Bullet's orchestrator sequences lifecycle work through **directives**, **Task workers**, and **hooks**. The parent session NEVER implements directly — cooperative single-agent mode is removed.

## Execution model

| Role | Session | May implement? | Tools |
|------|---------|----------------|-------|
| **Parent** | Main agent / `/silver` | **No** | Task, Read, Grep, Glob; Skill: `silver` / `silver-orchestrator` only |
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
| `${SB_RUNTIME_STATE_DIR}/orchestrator-worker-active.json` | Session | Parent Task spawn handoff metadata |
| `.silver-bullet/orchestrator-workers/*.md` | Project | Worker prompt templates (stamped by `silver:init`) |
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

Written by `flow-advance.sh`, `orchestrator-state.sh`, `outcomes-check.sh`. Cleared by `record-skill.sh` or audited `SB OVERRIDE:`.

## Parent loop

```
User intent → /silver or silver-orchestrator
  → composer spec seeds orchestrator.json + workflows.sh
  → directive: next_skill + next_worker_template
  → parent spawns Task with .silver-bullet/orchestrator-workers/<TEMPLATE>.md
  → worker invokes next_skill → implements flow
  → SubagentStop clears worker marker
  → flow-advance writes next directive
  → repeat until queue empty
```

## Worker contract

Each worker template (`templates/orchestrator-workers/`) includes:

- Flow contract reference (`docs/composable-flows-contracts.md`)
- Mandatory skill invocation
- Acceptance criteria and handoff artifacts

Workers should run with `SB_ORCHESTRATOR_WORKER=1` (set in Task prompt) so hooks apply worker directive-guard semantics.

## Enforcement (tier ≥ 2)

| Hook | Parent behavior | Worker behavior |
|------|-----------------|-----------------|
| `orchestrator-directive-guard.sh` | Blocks Edit/Write/Bash; allows Task; blocks direct flow Skill | Blocks until `next_skill` recorded |
| `stop-check.sh` | Blocks Stop while `current_flow` pending | SubagentStop clears worker marker |
| `prompt-reminder.sh` | Injects directive + parent mode banner | Injects directive |
| `session-start` | Parent mode context | Worker when `SB_ORCHESTRATOR_WORKER=1` |

### Cursor / tier 0–1

Guidance only — `templates/cursor-rules/silver-orchestrator.mdc` + directive injection. Tier 2+ required for mechanical parent blocks.

## Host modes — Plan & Debug (E2E-013)

Silver Bullet hooks do **not** read host mode from stdin today. Operators and agents should treat modes as follows:

| Host mode | Parent may | SB enforcement |
|-----------|------------|----------------|
| **Agent (default)** | Spawn Task workers; read-only Bash in parent | Full PreToolUse/Stop stack |
| **Plan** (`SwitchMode` → plan) | Read/Grep/Glob + Task PLAN worker; **no** direct Edit/Write in parent | `orchestrator-directive-guard` still blocks parent writes; route planning via workers |
| **Debug** | Route to `silver:debug` / `silver:forensics` queue — not freestyle Bash | Stop/PreToolUse still fire; use `SB OVERRIDE:` only for audited bypass |
| **Ask** | Read-only tools | Aligns with parent read-only subset |

**Enterprise E2E:** Matrix rows run in autonomous Agent mode. Do not switch to Plan/Debug mid-row — outcome scorers expect worker completion markers.

**Future:** SessionStart may inject `SB PLAN MODE` context when hosts expose mode hints reliably.

## SubagentStop semantics

- **Worker SubagentStop:** Clears `orchestrator-worker-active.json`; does not block (parent continues).
- **Parent Stop:** Blocked while orchestrator queue has pending `current_flow` — parent must spawn next Task worker.

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
