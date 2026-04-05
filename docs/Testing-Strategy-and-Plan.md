# Testing Strategy and Plan

## Testing Pyramid

```
    / Static assertions \   JSON config validation, template parity, doc content grep
   / Hook unit tests    \   Bash test scripts per hook in tests/hooks/
  / Manual smoke tests  \   /using-silver-bullet setup on a fresh project
```

Silver Bullet's test surface is primarily shell hooks and JSON configuration — no application
server, no database, no frontend. The bulk of coverage is fast static and unit tests.

## Test Classification

| Type | What | Location | Speed |
|------|------|----------|-------|
| **Static — JSON** | Validate `required_deploy`/`all_tracked` correctness; ensure config template mirrors live config | CI step / jq assertions | <1s |
| **Static — template parity** | `diff docs/workflows/ templates/workflows/` byte-for-byte | CI step | <1s |
| **Static — doc content grep** | Assert REQUIRED markers and skill names in workflow files | CI step | <1s |
| **Hook unit — bash** | Each hook exercised with mocked state; verify correct output per scenario | `tests/hooks/test-*.sh` | <5s each |
| **Script unit — bash/node** | Semantic compress, TF-IDF rank, extract-phase-goal | `tests/scripts/test-*.sh` | <10s each |
| **Manual smoke** | Run `/using-silver-bullet` on a clean project; verify enforcement activates | Human | 5-10 min |

## Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| `record-skill.sh` | 100% of skip/record paths | Covered by compliance-status tests (indirect) |
| `dev-cycle-check.sh` | 100% of Stage A/B/C/D + trivial bypass | **0%** — no test file (tech debt) |
| `compliance-status.sh` | Key progress calculation paths | Covered via integration patterns |
| `completion-audit.sh` | block vs. pass for each required skill group | Partial |
| `ci-status-check.sh` | failed/passing/missing CI output | 100% (`test-ci-status-check.sh`) |
| JSON config correctness | required_deploy + all_tracked exact-match assertions | **0%** — CI gap (tech debt) |
| Template parity | docs/ == templates/ | **0%** — CI gap (tech debt) |

## Phase 2 — New Test Requirements

### Priority 1: Config JSON CI assertions (score 35)
```yaml
- name: Validate required_deploy contents
  run: |
    jq -e '.skills.required_deploy | contains(["test-driven-development","tech-debt"])' \
      .silver-bullet.json
    jq -e '.skills.required_deploy | contains(["accessibility-review"]) | not' \
      .silver-bullet.json
    jq -e '.skills.all_tracked | contains(["test-driven-development","tech-debt","accessibility-review","incident-response"])' \
      .silver-bullet.json

- name: Config template parity
  run: |
    diff <(jq '.skills' .silver-bullet.json) \
         <(jq '.skills' templates/silver-bullet.config.json.default)
```

### Priority 2: Template parity CI step (score 30)
```yaml
- name: Workflow template parity
  run: |
    diff docs/workflows/full-dev-cycle.md templates/workflows/full-dev-cycle.md
    diff docs/workflows/devops-cycle.md templates/workflows/devops-cycle.md
```

### Priority 3: `dev-cycle-check.sh` unit tests (score 24)
Create `tests/hooks/test-dev-cycle-check.sh` with 7 cases:
1. Stage A blocks if `quality-gates` absent from state
2. Phase-skip detection: finalization skill present but no `code-review` → BLOCKED
3. Stage B: planning done, no `code-review` → BLOCKED
4. Stage C: `code-review` present, finalization hint includes `/tech-debt`
5. Stage C: `tech-debt` out-of-order (before `code-review`) → phase-skip BLOCKED
6. Stage D: all required skills present → silent pass
7. Trivial file present → never blocks regardless of state

## Skip Policy

Do **not** test:
- The markdown prose inside workflow/skill files (no executable logic)
- Third-party plugin hooks (GSD, Superpowers enforce their own behavior)
- Trivial config scaffolding (placeholder presence is already tested in CI)
