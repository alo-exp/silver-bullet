# Silver Orient Skill Scenario

## Skill: silver-orient
## Context: Legacy gsd-scan / gsd-map-codebase alias

### Scenario: Record legacy orientation marker

**Trigger:** Agent invokes `gsd-scan`, `gsd-map-codebase`, or `silver-orient`

**Workflow:**
1. Enforcement records the virtual `silver-orient` marker.
2. Route orientation to `/silver:scan` or phase context to `/silver:context`.
