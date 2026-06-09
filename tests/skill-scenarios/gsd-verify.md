# GSD Verify Skill Scenario

## Skill: gsd-verify
## Context: Test verification

### Scenario: Verify Test Coverage

**Trigger:** "Verify all paths are tested"

**Workflow:**
1. Run → coverage report
2. Check → threshold (80%+)
3. Identify → untested paths
4. Add → missing tests
