# Silver Agent OpenCode Skill Scenario

## Skill: silver-agent-opencode
## Context: Parent-supervised OpenCode CLI delegation for a single real task

### Scenario: Delegate backend fix to OpenCode

**Trigger:** "Have OpenCode implement the API handler fix while I supervise from Cursor"

**Workflow:**
1. Parent writes structured brief with acceptance criteria under `.planning/agent-opencode/<task-id>/`
2. Parent invokes `/sb:agent-opencode` and seeds delegation directive with ownership scope
3. Parent runs the OpenCode delegate script once per delegation wave
4. Parent verifies acceptance criteria before claiming done — no direct source edits in delegated scope
