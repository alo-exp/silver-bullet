# Silver Review Triage Skill Scenario

## Skill: silver-review-triage
## Context: Review finding handling (wrapper for sb:triage)

### Scenario: Triage Review Findings

**Trigger:** "Address review feedback"

**Workflow:**
1. Delegate to `/sb:triage` with raw review findings and scope.
2. Classify findings by severity and actionability via generic triage.
3. File valid items through `/sb:add`; reject false positives with evidence.
4. Route blockers to fix workflows; record deferred work in PM.
5. Verify fixes against the original finding when fixes are applied in-session.

