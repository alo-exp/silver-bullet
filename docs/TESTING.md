# Testing Strategy and Plan

## Testing Pyramid

```
    / Static assertions \   JSON config validation, template parity, doc content grep
   / Hook unit tests    \   Bash test scripts per hook in tests/hooks/
  / Manual smoke tests  \   /sb:init setup on a fresh project
```

Silver Bullet's test surface is primarily shell hooks, JSON configuration, and packaging
glue — no application server, no database, no frontend. The bulk of coverage is fast static
and unit tests, plus a shared live matrix that exercises the real Kay-backed Codex-compatible path.

## Test Classification

| Type | What | Location | Speed |
|------|------|----------|-------|
| **Static — JSON** | Validate `required_deploy`/`all_tracked` correctness; ensure config template mirrors live config | CI step / jq assertions | <1s |
| **Static — template parity** | `diff docs/workflows/ templates/workflows/` byte-for-byte | CI step | <1s |
| **Static — doc content grep** | Assert REQUIRED markers and skill names in workflow files | CI step | <1s |
| **Hook unit — bash** | Each hook exercised with mocked state; verify correct output per scenario | `tests/hooks/test-*.sh` | <5s each |
| **Script unit — bash** | Semantic compress, TF-IDF rank, extract-phase-goal | `tests/scripts/test-*.sh` | <10s each |
| **Generic five-tool runtime** | No-SB install/validate/repair, legacy migration, one-instance coordination, five projections, and Windows launcher/path fixtures | `tests/scripts/test-generic-five-tool-runtime.sh` | <2s |
| **Codex package sync/install** | SB-only Codex bundle, marketplace registration, dependency bootstrap, legacy skill purge | `scripts/install-codex.sh`, `scripts/sync-codex-package.sh` | <10s each |
| **Live AI matrix** | Shared scenario suite on the Kay agent adapter using the Codex-compatible hook surface | `tests/live/run-live-tests.sh` | 5-15 min |
| **Live enterprise E2E** | Kay hook-delivery diagnostic against the standalone sibling `enterprise-grade-test-app` repo; full workflow matrix via Claude supervised sessions | `tests/e2e-live/run-e2e-live-tests.sh` + `.planning/enterprise-e2e/` | 10-30 min (Kay) / multi-day (Claude matrix) |
| **Manual smoke** | Run `/sb:init` on a clean project; verify enforcement activates | Human | 5-10 min |

## Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| `record-skill.sh` | 100% of skip/record paths | Covered by compliance-status tests (indirect) |
| `dev-cycle-check.sh` | 100% of Stage A/B/C/D + legacy trivial-marker compatibility | **Covered** by `tests/hooks/test-dev-cycle-check.sh` |
| `compliance-status.sh` | Key progress calculation paths | Covered via integration patterns |
| `completion-audit.sh` | block vs. pass for each required skill group | Partial |
| `verify-tests.sh` | Configured commands, stack fallback, marker write, failure path | **Covered** by `tests/hooks/test-verify-tests.sh` |
| `ci-status-check.sh` | failed/passing/missing CI output | 100% (`test-ci-status-check.sh`) |
| SB Codex packaging | package scope, marketplace registration, dependency bootstrap | 100% (`test-install-codex.sh`, `test-sync-codex-package.sh`) |
| Live Kay matrix | shared scenarios, isolated Kay adapter, release-gate hook enforcement | 100% (`tests/live/run-live-tests.sh`) |
| Live enterprise E2E | Kay hook-failure diagnostic on `enterprise-grade-test-app`; Claude supervised 22-row matrix is the canonical full-surface gate | Kay: `tests/e2e-live/run-e2e-live-tests.sh`; Claude: `.planning/enterprise-e2e/` |
| JSON config correctness | required_deploy + all_tracked exact-match assertions | ✅ CI enforced (v0.26.0) |
| Template parity | docs/ == templates/ | ✅ CI enforced (v0.26.0) |
| Release identity parity | package, plugin, marketplace, config, catalog, README, and security support series | **Covered** by `tests/scripts/test-release-version-alignment.sh` |
| Documentation governance | unique live-guidance inventory, exact task-checklist coverage, historical-evidence exclusion | **Covered** by `tests/docs/test-documentation-scheme.sh` |
| Generic five-tool runtime | manifest schema, idempotent repair, host projections, Windows fixtures | **Covered** by `tests/scripts/test-generic-five-tool-runtime.sh` |

## Silver Bullet Test Execution Gate

Silver Bullet treats test execution as a freshness-gated step, not just a planning note.

- Run `/verify-tests` after the last source change and before `gh pr create`, deploy, or `gh release create`
- The skill executes `.silver-bullet.json` `verify_commands` when present, otherwise it falls back to stack defaults such as `tests/run-all-tests.sh`, `npm test`, `pytest`, `cargo test`, or `go test ./...`
- `tests/run-all-tests.sh` invokes each `test-*.sh` with `</dev/null` so hooks that read stdin do not hang when the runner captures output via command substitution (fixed v0.39.2 — without the redirect, `input=$(cat)` in hook tests blocks the full 3000+ test suite indefinitely in agent shells)
- The aggregate runner counts a non-zero test-file exit even when that file terminates before printing a `Results:` summary; suite totals cannot silently report green after an early failure.
- Default structural tests are hermetic. Assertions against the live sibling enterprise fixture are opt-in with `SB_TEST_ENTERPRISE_FIXTURE_STATE=1`; live/certification gates own external branch state.
- Tri-host install smoke must leave generated runtime mirrors unchanged. Installer caches dereference package symlinks outside the source checkout.
- Manifest-generator tests write to temporary output directories; frozen historical audit manifests are validation inputs, not mutable test fixtures.
- On success, the skill writes `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state`
- `completion-audit.sh` blocks final delivery if the marker is missing after `/verify-tests` was recorded, and `dev-cycle-check.sh` invalidates the marker whenever source edits land

### `run-all-tests.sh` stdin redirect (v0.39.2)

`tests/run-all-tests.sh` captures per-test output with:

```bash
output=$(bash "$test_file" </dev/null 2>&1)
```

Without `</dev/null`, the subshell inherits the parent agent shell's open stdin. Hook tests that read input via `input=$(cat)` block indefinitely and the 3000+ test suite appears hung. Individual hook tests should pipe explicit JSON when exercising stdin paths.

## Phase 2 — New Test Requirements

> **Status:** Priorities 1 and 2 implemented in v0.26.0 (CI-02 and CI-01). Priority 3 remains open (SB-B-3 backlog).

### Priority 1: Config JSON CI assertions (score 35) ✅ Done — v0.26.0
```yaml
- name: Validate required_deploy contents
  run: |
    jq -e '.skills.required_deploy | contains(["tdd","verify-tests"])' \
      .silver-bullet.json
    jq -e '.skills.required_deploy | contains(["accessibility-review"]) | not' \
      .silver-bullet.json
    jq -e '.skills.all_tracked | contains(["tdd","silver-bootstrap-project","silver-orient"])' \
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
4. Phase-skip detection warns when finalization skills appear before `/sb:review` while still allowing fixes
5. Stage C allows edits once `silver-review` is done and finalization remains
6. Stage D allows edits once all required skills are present
7. Trivial file bypass never blocks, regardless of state
8. State tamper, plugin boundary, and devops-cycle regressions are covered in the same suite

## Live AI Matrix (separate suite)

Not part of CI — run manually with real model/API usage via
`tests/live/run-live-tests.sh`.

| Test file | What it covers |
|-----------|---------------|
| `tests/live/test-live-enforcement.sh` | S1-S4 enforcement scenarios (blocking, planning gate, forbidden skills, stop-check) |
| `tests/live/test-live-skill-recording.sh` | S5-S6 skill recording and compliance-status output |
| `tests/live/test-live-full-scenario.sh` | S7-S8 session initialization and abbreviated SDLC lifecycle |
| `tests/live/test-live-doc-scheme.sh` | Doc scaffolding from scratch, finalization appends, CHANGELOG prepend, INDEX.md update, learnings portability, monthly boundary freeze |
| `tests/live/test-silver-init-migration.sh` | On-demand doc-scheme migration test: no-docs skip, unrecognized files skip, architecture doc detection, skip option, backup + rename, knowledge/learnings split |

The suite invokes Kay through the Codex-compatible adapter in
`tests/live/agents/` by default. The standard combination is
MiniMax.io + `MiniMax-M3` + low reasoning in isolated envs.
Claude or native Codex runs are optional diagnostics only when explicitly
requested.

The live enterprise E2E suite is separate. It uses the standalone sibling
`enterprise-grade-test-app` repo for Kay hook-delivery diagnostics and writes its own
`e2e-live-matrix` marker. The **canonical full-surface gate** is the Claude supervised
22-row workflow matrix (`.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md`,
`enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md`).

The legacy Kay inline todo-app full-surface journey is retired from the default
scenario list. Set `SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1` to run the archived script.

The Kay diagnostic path verifies hook delivery against `api/src/health.js` in the
enterprise fixture. Release gates accept either Kay `matrix=codex-only` markers from
this suite or Claude supervised matrix evidence recorded in round ledgers.

The separate `tests/live/test-silver-init-migration.sh` scenario exercises the
Step 3.5.5 delegation path where `sb:init` hands docs bootstrap/reconciliation
to `sb:ensure-docs`. It validates the brownfield preserve-vs-switch behavior,
archive-move policy, and recovery/remediation command paths.

## Skill Scenario Coverage

The skill scenario coverage test validates that each SB-owned source skill has a scenario fixture under `tests/skill-scenarios/`.

### Test Classification

| Type | What | Location | Speed |
|------|------|----------|-------|
| **Skill scenario tests** | Each skill has documented trigger + workflow | `tests/skill-scenarios/*.md` | <5s |
| **Coverage guard** | Every source skill has a scenario fixture | `tests/scripts/test-sb-skill-scenario-coverage.sh` | <5s |

### Coverage Contract

Every source `skills/*/SKILL.md` must have a matching scenario fixture. The scenario directory may also contain capability-level fixtures, so its raw file count is not a canonical skill count. `tests/scripts/test-sb-skill-scenario-coverage.sh` computes coverage from the current source tree and fails on a missing source-skill scenario.

### Running the Harness

```bash
bash tests/scripts/test-sb-skill-scenario-coverage.sh
```

### Skill Trigger Examples

| Skill | Trigger Phrase |
|-------|---------------|
| `silver-feature` | "I need to add a feature" |
| `silver-bugfix` | "The delete button doesn't work" |
| `tdd` | "Add feature using TDD" |
| `silver-execute` | "Implement the endpoint" |
| `silver-secure` | "Audit API for vulnerabilities" |

### Adding New Skill Scenarios

Create `tests/skill-scenarios/{skill-name}.md`:

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

## Session note (2026-06-14)

Doc-scheme gate remediation for `phase-056-zuvo-runtime-parity-release` in a Cursor session did not change test commands, harness layout, or coverage targets; prior v0.39.2 `run-all-tests.sh` stdin guidance remains authoritative.

## Doc-scheme session (2026-06-14)

Task `phase-056-zuvo-runtime-parity-release`: v0.40.0 shipped (phase 056 runtime parity, phase 057 Cursor marketplace, site refresh). Doc-scheme gate refreshed in Cursor runtime (`~/.cursor/.silver-bullet`).


## Cursor runtime bootstrap (v0.40.0 / phase 057)

Phase 057 adds targeted coverage for the Cursor host adapter:

| Area | What it proves | Location |
|------|----------------|----------|
| Runtime paths | `$HOME/.cursor/.silver-bullet` state + hook manifest resolution | `tests/hooks/test-runtime-paths.sh` (cursor cases) |
| Bootstrap / install | Marketplace sync, plain-file template layout, local git identity on CI | `tests/hooks/test-cursor-runtime-bootstrap.sh` |
| Hook bridge | Cursor `exec_command` / patch events reach SB PreToolUse hooks | `tests/hooks/test-cursor-hook-bridge.sh` |

Run the focused slice before release:

```bash
bash tests/hooks/test-cursor-runtime-bootstrap.sh
bash tests/hooks/test-cursor-hook-bridge.sh
```

Full suite still gates delivery via `/verify-tests` → `tests/run-all-tests.sh` (stdin closed per test).
