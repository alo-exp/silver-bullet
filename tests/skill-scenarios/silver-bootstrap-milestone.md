# Silver Bootstrap Milestone Skill Scenario

## Skill: silver-bootstrap-milestone
## Context: Legacy gsd-new-milestone alias

### Scenario: Record legacy milestone bootstrap marker

**Trigger:** Agent invokes `gsd-new-milestone` or `silver-bootstrap-milestone`

**Workflow:**
1. Enforcement records the virtual `silver-bootstrap-milestone` marker.
2. Route new work to `/silver:feature` or `/silver:clarify` instead of legacy GSD flows.
