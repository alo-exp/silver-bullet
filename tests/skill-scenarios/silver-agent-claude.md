# Silver Agent Claude Skill Scenario

## Skill: silver-agent-claude
## Context: Parent-supervised Claude TUI delegation for a single real task

### Scenario: Delegate implementation wave to Claude

**Trigger:** "Delegate the Redis cache implementation to Claude while I supervise from Cursor"

**Workflow:**
1. Parent writes structured brief with acceptance criteria under `.planning/agent-claude/<task-id>/`
2. Parent invokes `/silver:agent-claude` and seeds delegation directive with ownership scope
3. Parent runs `bash scripts/agent-claude/invoke.sh` once per delegation wave
4. Parent verifies acceptance criteria before marking outcomes complete — no direct source edits in delegated scope
