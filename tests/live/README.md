# Silver Bullet Live AI E2E Tests

These tests invoke the **real Kay-backed agent** with the Silver Bullet plugin
loaded and stored credentials. The standard path uses Kay's `opencode-go`
provider credentials with `deepseek-v4-flash` and low reasoning for isolated
live testing. They verify that SB enforcement hooks
(dev-cycle-check, record-skill, stop-check, compliance-status, forbidden-skill-check)
actually work when the live agent triggers them via real tool usage.

## Prerequisites

- Kay `v0.9.6` available in `PATH` for Kay-agent runs
- `opencode-go` credentials available through the user's Kay config
- Authenticated with valid credentials for the Kay profile you plan to run
- `jq` installed (`brew install jq`)
- Git available

## Cost Warning

**Each Kay live run has real model/API cost.**

- Cheapest subset (skill recording only): ~\$0.02-\$0.10

## Running the Tests

Run the default Kay-only suite:
```bash
bash tests/live/run-live-tests.sh
```

Run the Kay-only live suite wrapper:
```bash
bash scripts/run-sb-live-tests-kay.sh
```

Run a single agent to validate setup:
```bash
bash tests/live/test-live-skill-recording.sh
```

Run individual scenario files:
```bash
bash tests/live/test-live-enforcement.sh
bash tests/live/test-live-skill-recording.sh
bash tests/live/test-live-full-scenario.sh
```

## Test Scenarios

| File | Scenarios | What it tests |
|------|-----------|---------------|
| test-live-enforcement.sh | S1-S4 | HARD STOP blocking, planning gate, forbidden skills, stop-check |
| test-live-skill-recording.sh | S5-S6 | Skill recording to state file, compliance-status output |
| test-live-full-scenario.sh | S7-S8 | Session initialization, abbreviated SDLC lifecycle |
| test-live-doc-scheme.sh | Doc scheme | Doc scaffolding, monthly knowledge/lessons updates, filename conventions |
| test-silver-init-migration.sh | Init docs bootstrap | `silver:init` Step 3.5.5 delegation to `silver:ensure-docs`, brownfield preserve-vs-switch, archive move/recovery paths |

## Isolation

Each agent run uses:
- An isolated temp workspace directory (`mktemp -d`)
- Isolated state files: `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/live-test-state-{PID}`
- Isolated trivial files: `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/live-test-trivial-{PID}`
- For Kay-agent runs, an isolated temporary `KAY_HOME` root backed by Kay's
  `opencode-go` provider path so the test installer never rewrites the user's
  real `~/.codex` hook cache.
- Native Codex isolated runs use Codex's supported
  `--dangerously-bypass-hook-trust` flag and auto-accept the one-time hook
  review inside the temporary isolated home only, so the live harness tests
  actual hook delivery without depending on forged private trust hashes or
  touching the user's real trust state.
- Kay isolated runs auto-accept the one-time hook review inside the temporary
  isolated home only, so the persisted trust state stays local to that temp
  tree and never touches the user's real config.

The matrix can run multiple adapters sequentially for ad hoc diagnostics, but
the standard release/reliability path is Kay only. All temp files are cleaned
up after each scenario.
When the Kay-only matrix passes, `run-live-tests.sh` writes the
session-scoped `release-live-matrix` marker (`matrix=codex-only`) that
`completion-audit.sh` requires before `gh release create`.
Those `matrix=codex-only` markers are now the standard release prerequisite
because the release gate is defined on the Kay Codex-compatible path.

The live harness keeps a small local archive of captured Kay transcripts under
`tests/live/agents/kay/transcripts/` for rotation and debugging. The Kay live
state itself lives under `${KAY_HOME}/.kay/.silver-bullet/` inside the
isolated temp tree. That archive is separate from the official agent session
stores that `silver-scan` reads.

The separate todo-app suite at `tests/e2e-live/run-e2e-live-tests.sh` writes a
matching `e2e-live-matrix` marker. That suite now runs one inline full-surface
journey against the standalone sibling `test-todo-app` repo and also writes an `inline-e2e-matrix` marker so the release gate can
prove the end-user experience actually ran in this session. Both markers must
be present before a release can proceed.

The init-docs bootstrap scenario is a separate on-demand test for
`skills/silver-init/SKILL.md` (Phase 3.5.5) and is not part of the default
`run-live-tests.sh` matrix.

## Not Included in Unit/Integration Suites

These tests are **NOT** included in `run-all-tests.sh`. Run them separately via
`run-live-tests.sh` when you need to validate real AI + hook integration.
