# Silver Agent Codex Skill Scenario

## Skill: silver-agent-codex
## Context: Parent-supervised Codex TUI delegation for a single real task

### Scenario: Delegate implementation wave to Codex

**Trigger:** "Delegate the Redis cache implementation to Codex while I supervise from Cursor"

**Workflow:**
1. Parent writes structured brief with acceptance criteria under `.planning/agent-codex/<task-id>/`
2. Parent invokes `/silver:agent-codex` and seeds delegation directive with ownership scope
3. Parent runs `bash scripts/agent-codex-delegate.sh` once per delegation wave
4. Parent verifies acceptance criteria before marking outcomes complete — no direct source edits in delegated scope
