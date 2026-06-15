# Silver Bootstrap Project Skill Scenario

## Skill: silver-bootstrap-project
## Context: Legacy gsd-new-project alias

### Scenario: Record legacy project bootstrap marker

**Trigger:** Agent invokes `gsd-new-project` or `silver-bootstrap-project`

**Workflow:**
1. Enforcement records the virtual `silver-bootstrap-project` marker.
2. Route new work to `/silver:init` instead of legacy GSD project bootstrap.
