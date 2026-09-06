# Silver Agent Cursor Skill Scenario

## Skill: silver-agent-cursor
## Context: Parent-supervised Cursor subagent delegation for a single real task

### Scenario: Delegate UI polish wave to Cursor

**Trigger:** "Have Cursor implement the responsive nav fixes while I supervise from Claude"

**Workflow:**
1. Parent writes structured brief with acceptance criteria under `.planning/agent-cursor/<task-id>/`
2. Parent invokes `/sb:agent-cursor` and seeds delegation directive with ownership scope
3. Parent runs `bash scripts/agent-cursor-delegate.sh` once per delegation wave (Composer 2.5 only for nested Tasks)
4. Parent verifies acceptance criteria before claiming done — no direct source edits in delegated scope
