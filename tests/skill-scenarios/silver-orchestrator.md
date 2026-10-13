# Silver Orchestrator Skill Scenario

## Skill: silver-orchestrator
## Context: Parent-mode orchestration for autonomous SB workflows

### Scenario: Queue next flow worker after directive update

**Trigger:** "Continue the orchestrator queue for the active feature workflow"

**Workflow:**
1. Read `orchestrator-directive.json` and `orchestrator.json` for pending flow
2. Select worker template from `.silver-bullet/orchestrator-workers/<FLOW>.md`
3. Spawn Task worker with template prompt — parent never edits source directly
4. On worker completion, advance queue and spawn next flow or clear directive
