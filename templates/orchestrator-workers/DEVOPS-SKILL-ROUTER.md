# SB Orchestrator Worker — DEVOPS SKILL ROUTER

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Mandatory tooling (worker)

1. **Graphify first** — run `graphify query "<question>"` before Read/Grep/Glob exploration (mandatory when `graphify-out/` exists).
2. **agentmemory** — save decisions, defects, and session evidence via agentmemory MCP after meaningful work.
3. **Evidence artifact** — write a durable evidence path (`.planning/` file or agentmemory export) before your exit summary.
4. **Assigned skill** — invoke the mandatory skill listed below before substantive edits.
5. **RTK / Context Mode** — follow project token-compression rules when opted in.

## Contract

`skills/silver-devops/SKILL.md` — **Step 2: DevOps Skill Router**

## Mandatory skill

Invoke **`devops-skill-router`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- IaC/cloud tooling route is selected and recorded for the change

## Handoff artifacts

- Router decision notes in planning or SUMMARY artifacts

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.
