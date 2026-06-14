# Silver Bullet Orchestrator Contract

**Status:** In-repo mechanical orchestration (2026-06-14, P0 10/10 program)

Silver Bullet's orchestrator sequences lifecycle work through **directives** and **hooks**, not by auto-invoking the host Skill tool (that remains a host capability).

## State surfaces

| File | Scope | Purpose |
|------|-------|---------|
| `${SB_RUNTIME_STATE_DIR}/orchestrator.json` | Session/branch | Intent, `flow_queue`, `current_flow`, `workflow_id` |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json` | Session/branch | **Mandatory next skill** when `blocking: true` |
| `${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt` | Session | Latest user intent (first line) |
| `.planning/orchestrator-composition-log.jsonl` | Committed | Autonomous composition audit (M-05) |
| `.planning/orchestrator-override-log.jsonl` | Committed | User `SB OVERRIDE:` audit trail |

## Directive schema (`orchestrator-directive.json`)

```json
{
  "next_skill": "silver-quality-gates",
  "args": "optional intent snippet",
  "reason": "human-readable why",
  "blocking": true,
  "updated_at": "2026-06-14T12:00:00Z"
}
```

Written by:

- `hooks/flow-advance.sh` / `hooks/lib/orchestrator-state.sh` when a flow atom completes
- `hooks/outcomes-check.sh` when per-prompt outcomes are pending (maps outcome id → skill)
- `hooks/lib/orchestrator-state.sh` on composer start (first queued flow)

Cleared by:

- `hooks/record-skill.sh` when the expected skill is recorded
- User prompt containing `SB OVERRIDE: <reason>` (logged, then cleared)

## Enforcement (tier ≥ 2)

| Hook | Behavior |
|------|----------|
| `orchestrator-directive-guard.sh` | PreToolUse: blocks Edit/Write/Bash until `next_skill` recorded or override |
| `prompt-reminder.sh` | Injects directive text every user prompt |
| `session-start` | Re-injects directive + tier banner at session open |

### Cursor / tier 0–1 substitute

Hosts without PreToolUse hooks (tier 0) receive **guidance only** — directives are injected but not mechanically enforced.

On **Cursor with merged hooks** (tier 2): the guard blocks non-skill tools until `PostToolUse/Skill` records the expected skill — the strongest in-repo substitute for auto-invoke.

## Host contract for true auto-invoke (future)

To reach full autonomous skill execution (not just block-until-invoked):

| Host | Today | Target |
|------|-------|--------|
| Claude Code | `PostToolUse/Skill` records; agent must invoke Skill | Session hook reads `orchestrator-directive.json` and schedules Skill tool |
| Codex | `silver-bullet invoke-skill` adapter + receipt | Same directive → adapter auto-call |
| Cursor | Skill channel + hooks.json + `.cursor/rules/silver-orchestrator.mdc` (stamped by `silver:init`) | SDK/Cursor automation invokes skill from directive |
| SDK / web | Tier 0 | Not supported until hook manifest merged |

**In-repo Cursor substitute (2026-06-14):** `prompt-reminder.sh` leads with the directive block; `orchestrator-directive-guard.sh` blocks Edit/Write/Bash at tier ≥ 2; `templates/cursor-rules/silver-orchestrator.mdc` tells the agent to invoke `next_skill` before any tool use. This is convention + block until Cursor exposes Skill scheduling.

**Required host behaviors for auto-invoke:**

1. Read `${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json` after each skill completion
2. When `blocking: true`, invoke `next_skill` with `args` before any Edit/Write/Bash
3. Emit `PostToolUse/Skill` so `record-skill.sh` clears the directive
4. Never skip override audit when user sends `SB OVERRIDE:`

## Flow advance

```
User intent → outcomes-check seeds → silver router (skill)
     → composer skill → flow-advance seeds orchestrator.json + workflows.sh
     → flow atoms → flow-advance writes directive for next atom
     → directive-guard blocks edits until next skill invoked
     → delivery gates (completion-audit, substance, tier)
```

## Related docs

- `docs/RUNTIME-COMPATIBILITY.md` — capability tiers 0–3
- `docs/evidence-schema.md` — artifact substance at delivery
- `.planning/phases/launch-remediation/CHECKLIST-10-10.md` — gap program tracker
