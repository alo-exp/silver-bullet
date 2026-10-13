# Silver Domain Audit Skill Scenario

## Skill: silver-domain-audit
## Context: Specialized quality contracts

### Scenario: Audit API And Data Changes Before Release

**Trigger:** "Run domain audit on the API and migration changes"

**Workflow:**
1. Select packs -> `api-contract`, `data-contract`, `test-health`
2. Gather evidence -> changed routes, migrations, tests, command output
3. Normalize findings -> severity, confidence, file/line, owner workflow
4. Route outcomes -> blockers fixed now, deferred warnings filed via `sb:add`
