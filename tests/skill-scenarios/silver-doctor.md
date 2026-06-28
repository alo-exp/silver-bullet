# Silver Doctor Skill Scenario

## Skill: silver-doctor
## Context: Install and activation audit

### Scenario: Post-Update Health Check

**Trigger:** "Run doctor after updating Silver Bullet"

**Workflow:**
1. Run → `bash scripts/sb-doctor.sh`
2. Interpret → PASS/WARN/FAIL for D1–D13 checks
3. Fix → remediate any FAIL lines (hooks, config, template drift)
4. Re-run → confirm overall doctor PASS before implementation work
