# Testing Strategy and Plan

## Testing Pyramid

```
    / Static assertions \   JSON config validation, template parity, doc content grep
   / Hook unit tests    \   Bash test scripts per hook in tests/hooks/
  / Manual smoke tests  \   /silver:init setup on a fresh project
```

Silver Bullet's test surface is primarily shell hooks, JSON configuration, and packaging
glue — no application server, no database, no frontend. The bulk of coverage is fast static
and unit tests, plus a shared live matrix that exercises the real Claude and Codex CLIs.

## Test Classification

| Type | What | Location | Speed |
|------|------|----------|-------|
| **Static — JSON** | Validate `required_deploy`/`all_tracked` correctness; ensure config template mirrors live config | CI step / jq assertions | <1s |
| **Static — template parity** | `diff docs/workflows/ templates/workflows/` byte-for-byte | CI step | <1s |
| **Static — doc content grep** | Assert REQUIRED markers and skill names in workflow files | CI step | <1s |
| **Hook unit — bash** | Each hook exercised with mocked state; verify correct output per scenario | `tests/hooks/test-*.sh` | <5s each |
| **Script unit — bash** | Semantic compress, TF-IDF rank, extract-phase-goal | `tests/scripts/test-*.sh` | <10s each |
| **Codex package sync/install** | SB-only Codex bundle, marketplace registration, dependency bootstrap, legacy skill purge | `scripts/install-codex.sh`, `scripts/sync-codex-package.sh` | <10s each |
| **Live AI matrix** | Shared scenario suite across Claude and Codex runtime adapters | `tests/live/run-live-tests.sh` | 5-15 min per runtime |
| **Live todo-app E2E** | Install UX plus real Claude/Codex development episodes against `tests/test-app/` | `tests/e2e-live/run-e2e-live-tests.sh` | 10-30 min per runtime |
| **Manual smoke** | Run `/silver:init` on a clean project; verify enforcement activates | Human | 5-10 min |

## Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| `record-skill.sh` | 100% of skip/record paths | Covered by compliance-status tests (indirect) |
| `dev-cycle-check.sh` | 100% of Stage A/B/C/D + trivial bypass | **Covered** by `tests/hooks/test-dev-cycle-check.sh` |
| `compliance-status.sh` | Key progress calculation paths | Covered via integration patterns |
| `completion-audit.sh` | block vs. pass for each required skill group | Partial |
| `ci-status-check.sh` | failed/passing/missing CI output | 100% (`test-ci-status-check.sh`) |
| SB Codex packaging | package scope, marketplace registration, dependency bootstrap | 100% (`test-install-codex.sh`, `test-sync-codex-package.sh`) |
| Live Claude/Codex matrix | shared scenarios, runtime adapters, sequential runtime execution | 100% (`tests/live/run-live-tests.sh`) |
| Live todo-app E2E | install-first + realistic feature / bugfix / release episodes on `tests/test-app/` | 100% (`tests/e2e-live/run-e2e-live-tests.sh`) |
| JSON config correctness | required_deploy + all_tracked exact-match assertions | ✅ CI enforced (v0.26.0) |
| Template parity | docs/ == templates/ | ✅ CI enforced (v0.26.0) |

## Phase 2 — New Test Requirements

> **Status:** Priorities 1 and 2 implemented in v0.26.0 (CI-02 and CI-01). Priority 3 remains open (SB-B-3 backlog).

### Priority 1: Config JSON CI assertions (score 35) ✅ Done — v0.26.0
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

### Priority 2: Template parity CI step (score 30) ✅ Done — v0.26.0
```yaml
- name: Workflow template parity
  run: |
    diff docs/workflows/full-dev-cycle.md templates/workflows/full-dev-cycle.md
    diff docs/workflows/devops-cycle.md templates/workflows/devops-cycle.md
```

### Priority 3: `dev-cycle-check.sh` unit tests (score 24) ✅ Done
`tests/hooks/test-dev-cycle-check.sh` covers the full gate matrix:
1. Stage A blocks if `quality-gates` is absent from state
2. Stage A warns and allows when the required skill is unavailable anywhere invocable
3. Stage A and Stage B both block source edits when planning is incomplete
4. Phase-skip detection blocks finalization skills before `/code-review`
5. Stage C allows edits once `code-review` is done and finalization remains
6. Stage D allows edits once all required skills are present
7. Trivial file bypass never blocks, regardless of state
8. State tamper, plugin boundary, and devops-cycle regressions are covered in the same suite

## Live AI Matrix (separate suite)

Not part of CI — run manually at roughly $0.10–$0.60 per full Claude+Codex matrix run via
`tests/live/run-live-tests.sh`.

| Test file | What it covers |
|-----------|---------------|
| `tests/live/test-live-enforcement.sh` | S1-S4 enforcement scenarios (blocking, planning gate, forbidden skills, stop-check) |
| `tests/live/test-live-skill-recording.sh` | S5-S6 skill recording and compliance-status output |
| `tests/live/test-live-full-scenario.sh` | S7-S8 session initialization and abbreviated SDLC lifecycle |
| `tests/live/test-live-doc-scheme.sh` | Doc scaffolding from scratch, finalization appends, CHANGELOG prepend, INDEX.md update, lessons portability, monthly boundary freeze |
| `tests/live/test-silver-init-migration.sh` | On-demand doc-scheme migration test: no-docs skip, unrecognized files skip, architecture doc detection, skip option, backup + rename, KNOWLEDGE.md split |

The suite invokes the real `claude` CLI or `codex` CLI with runtime adapters in
`tests/live/runtimes/`. By default `tests/live/run-live-tests.sh` runs both runtimes
sequentially; set `SB_LIVE_RUNTIMES=claude` or `SB_LIVE_RUNTIMES=codex` to narrow the
matrix. Sequential execution matters because both runtimes touch the same Silver Bullet
state path under `~/.claude/.silver-bullet/`.

The live todo-app E2E suite is separate. It uses the todo-app fixture in
`tests/test-app/`, writes its own `e2e-live-matrix` marker, begins with a
plugin-installation UX scenario, and is intended to prove the higher-level
product workflow on real runtime sessions. The install-UX scenario also
verifies the installed command surface (`silver:init`, `silver:feature`, and
the `silver` router) in the runtime cache, which is the closest reliable proxy
we currently have for picker exposure in the Codex/Claude hosts.
When Claude quota is exhausted and the user explicitly approves skipping further
Claude live testing for a release, the live runners may be narrowed to Codex
only via `SB_LIVE_RUNTIMES=codex` and `SB_E2E_LIVE_RUNTIMES=codex`, and the
release gate may be satisfied with `matrix=codex-only` markers after setting
`SB_ALLOW_CODEX_ONLY_LIVE_RELEASE=1`.

The separate `tests/live/test-silver-init-migration.sh` scenario exercises the interactive
migration step in `skills/silver-init/SKILL.md` (Phase 3.5.5). The migration is
non-destructive by design — originals are backed up as `.pre-sb-backup` before any rename
or split.

## Forge-Silver Bullet Skill Test Harness

The skill test harness (`tests/forge-test-app/run-forge-sb-tests.sh`) validates all 62 installed skills against realistic todo app development scenarios.

### Test Classification

| Type | What | Location | Speed |
|------|------|----------|-------|
| **API unit tests** | Todo API endpoints (CRUD, health) | `tests/forge-test-app/tests/api.test.js` | <1s |
| **Skill scenario tests** | Each skill has documented trigger + workflow | `tests/forge-test-app/SCENARIOS/*.md` | <5s |
| **Integration smoke** | Full harness runs all scenarios | `tests/forge-test-app/run-forge-sb-tests.sh` | <30s |

### Coverage Goals

| Skill Category | Skills | Coverage |
|---------------|--------|----------|
| Silver Core Workflow | 10 | 100% (scenario documented) |
| Silver Extended | 11 | 100% |
| GSD Workflow | 12 | 100% |
| Quality & Methodology | 10 | 100% |
| Review & Assessment | 11 | 100% |
| Planning & Documentation | 4 | 100% |
| DevOps & Routing | 2 | 100% |

**Total: 62 skills tested**

### Running the Harness

```bash
cd tests/forge-test-app
npm install  # Only needed once
bash run-forge-sb-tests.sh
```

### Skill Trigger Examples

| Skill | Trigger Phrase |
|-------|---------------|
| `silver-feature` | "I need to add a feature" |
| `silver-bugfix` | "The delete button doesn't work" |
| `tdd` | "Add feature using TDD" |
| `gsd-execute` | "Implement the endpoint" |
| `gsd-secure` | "Audit API for vulnerabilities" |

### Adding New Skill Scenarios

Create `tests/forge-test-app/SCENARIOS/{skill-name}.md`:

```markdown
# {Skill Name} Skill Scenario

## Skill: {skill-name}
## Context: One-line context

### Scenario: Brief description

**Trigger:** "trigger phrase"

**Workflow:**
1. Step one
2. Step two
3. Step three
```

The harness checks for scenario file existence — if found, skill shows ✓ in test output.

## Skip Policy

Do **not** test:
- The markdown prose inside workflow/skill files (no executable logic)
- Third-party plugin hooks (GSD, Superpowers enforce their own behavior)
- Trivial config scaffolding (placeholder presence is already tested in CI)
