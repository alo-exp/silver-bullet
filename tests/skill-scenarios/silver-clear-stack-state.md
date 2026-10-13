# Silver Clear Stack State Skill Scenario

## Skill: silver-clear-stack-state
## Context: Recovery from wedged stack compression mutex

### Scenario: Clear dirty mutex after double-compression wedge

**Trigger:** "Stack compression mutex is wedged — run clear-stack-state recovery"

**Workflow:**
1. Confirm → `sb_stack_double_compression` violation or D20 doctor WARN
2. Invoke → `/sb:clear-stack-state` or `bash scripts/sb-doctor.sh --fix`
3. Verify → compliant routed-owner tool call succeeds; mutex cleared
4. Record → agentmemory capture of recovery outcome before resuming work
