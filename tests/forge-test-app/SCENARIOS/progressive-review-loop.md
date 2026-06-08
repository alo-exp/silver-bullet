# Progressive Review Loop Skill Scenario

## Skill: progressive-review-loop
## Context: Close all actionable review findings before delivery

### Scenario: Iterate Until Review Is Clean

**Trigger:** "Run a progressive review loop on this todo API change"

**Workflow:**
1. Review → identify concrete correctness, security, or maintainability findings
2. Fix → apply the smallest safe change for each actionable finding
3. Re-review → verify the original findings are resolved and no new regressions appeared
4. Stop → report residual risks only after the loop reaches a clean or explicitly blocked state
