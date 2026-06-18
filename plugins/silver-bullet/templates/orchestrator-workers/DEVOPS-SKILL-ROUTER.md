# SB Orchestrator Worker — DEVOPS SKILL ROUTER

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
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
