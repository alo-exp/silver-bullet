# Silver Agent Worker Skill Scenario

## Skill: silver-agent-worker
## Context: External executor contract loaded by host delegate harnesses

### Scenario: Worker executes brief inside delegated ownership scope

**Trigger:** Host delegate launches external agent with `silver-agent-worker` contract

**Workflow:**
1. Load brief and ownership scope from parent delegation directive
2. Implement and verify only within scoped paths; write evidence to `.planning/agent-<host>/<task-id>/`
3. Report blockers in final message; do not expand scope without parent approval
4. Exit so parent can run acceptance verification before completion claims
