# Verify Tests Skill Scenario

## Skill: verify-tests
## Context: Run configured verification gates before claiming completion

### Scenario: Verify Todo App Test Freshness

**Trigger:** "Verify the todo app before I call this complete"

**Workflow:**
1. Resolve → read configured verification commands or stack defaults
2. Run → execute the full command set from the repo root
3. Record → write freshness evidence for downstream hooks
4. Report → state exact pass/fail output and block completion on failures
