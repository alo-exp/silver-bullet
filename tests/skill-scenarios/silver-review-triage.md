# Silver Review Triage Skill Scenario

## Skill: silver-review-triage
## Context: Review finding handling (wrapper for silver:triage)

### Scenario: Triage Review Findings

**Trigger:** "Address review feedback"

**Workflow:**
1. Delegate to `/silver:triage` with raw review findings and scope.
2. Classify findings by severity and actionability via generic triage.
3. File valid items through `/silver:add`; reject false positives with evidence.
4. Route blockers to fix workflows; record deferred work in PM.
5. Verify fixes against the original finding when fixes are applied in-session.

