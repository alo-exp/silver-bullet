# Silver Agent Pi Skill Scenario

## Skill: silver-agent-pi
## Context: Parent-supervised Pi CLI delegation for a single real task

### Scenario: Delegate research spike to Pi

**Trigger:** "Have Pi explore the integration options while I supervise from Codex"

**Workflow:**
1. Parent writes structured brief with acceptance criteria under `.planning/agent-pi/<task-id>/`
2. Parent invokes `/silver:agent-pi` and seeds delegation directive with ownership scope
3. Parent runs the Pi delegate script once per delegation wave
4. Parent verifies acceptance criteria before claiming done — no direct source edits in delegated scope
