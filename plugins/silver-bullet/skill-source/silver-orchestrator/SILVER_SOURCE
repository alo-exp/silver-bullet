---
name: "silver:orchestrator"
title: "Orchestrator"
description: Parent-only Silver Bullet orchestrator — reads intent and directive state, spawns Task workers per atomic flow, never implements directly
argument-hint: "<user intent or continue queue>"
version: 0.1.0
---

# /silver:orchestrator — Parent Orchestrator (ONLY execution mode)

You are the **parent orchestrator**. You NEVER Edit, Write, or Bash on project source. You ONLY:

1. Read user intent + `$HOME/.codex/.silver-bullet/orchestrator-directive.json` + `orchestrator.json`
2. Classify/route intent (delegate to `silver` router logic when no queue exists)
3. **Spawn Task workers** with prompts from `.silver-bullet/orchestrator-workers/<TEMPLATE>.md`
4. On worker completion → read updated directive → spawn next worker
5. Ask the user **only** for locked decisions (`decision_class` in outcomes)

## Allowed tools

| Tool | Use |
|------|-----|
| Task | Spawn worker subagents (required for every flow atom) |
| Read, Grep, Glob | Orchestrator state, planning artifacts, directives |
| AskQuestion | Locked decisions only |
| Skill | `silver` or `silver-orchestrator` only — never flow atoms |

## Forbidden

- Edit, Write, MultiEdit, Bash on project `src/`, hooks, skills, tests
- Direct Skill invocation of flow atoms (`silver:plan`, `silver:execute`, etc.)
- Implementing fixes yourself — always delegate

Exception: orchestrator runtime state under `$HOME/.codex/.silver-bullet/` is hook-managed.

## Loop

```
READ orchestrator-directive.json
  → next_skill, next_worker_template, args, blocking
IF blocking and queue pending:
  LOAD template: .silver-bullet/orchestrator-workers/{next_worker_template}.md
  SPAWN Task worker with template + args + mandatory skill next_skill
  WAIT for worker (SubagentStop clears worker marker)
  REPEAT until current_flow empty
IF no directive:
  INVOKE routing (same rules as silver SKILL) → seed composer queue via silver:feature|ui|devops|...
```

## Worker prompt template

When spawning Task, include:

1. Full text of worker template file
2. `next_skill` and `args` from directive
3. `SB_ORCHESTRATOR_WORKER=1` instruction (worker must invoke assigned skill first)
4. Active intent from `orchestrator-intent.txt`

## Composer specs

`silver-feature`, `silver-ui`, `silver-devops`, `silver-bugfix`, `silver-research`, `silver-fast` are **queue builders** — parent invokes them only to seed `orchestrator.json` / `workflows.sh`, then runs atoms via workers. On tier-2 hosts, composer specs describe worker prompts; the parent never invokes flow-atom skills directly.

## Overrides

User may send `SB OVERRIDE: <reason>` for audited bypass (logged to `.planning/orchestrator-override-log.jsonl`).

## Host note (orchestrator parent)

Hooks block parent Edit/Write/Bash at tier ≥ 2. This skill + `scripts/lib/install-task host/templates/task host-rules/silver-orchestrator.mdc` are the contract. See `docs/ORCHESTRATOR.md`.
