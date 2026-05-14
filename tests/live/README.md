# Silver Bullet Live AI E2E Tests

These tests invoke the **real `claude` CLI** or a **Kay-backed Codex-compatible
runtime** with the Silver Bullet plugin loaded and stored credentials. They verify that SB enforcement hooks
(dev-cycle-check, record-skill, stop-check, compliance-status, forbidden-skill-check)
actually work when either runtime triggers them via real tool usage.

## Prerequisites

- `claude` CLI installed at `/Users/shafqat/.local/bin/claude`
- Kay `v0.9.3` available in `PATH` for Codex-compatible runs
- MiniMax credentials available through `MINIMAX_API_KEY` or the user's Kay config
- Authenticated with valid credentials for the runtime(s) you plan to run
- `jq` installed (`brew install jq`)
- Git available

## Cost Warning

**Each full Claude+Codex matrix run costs approximately $0.10-$0.60.**

- One runtime only: roughly half that
- Cheapest subset (skill recording only, one runtime): ~\$0.02-\$0.10

## Running the Tests

Run the full matrix:
```bash
bash tests/live/run-live-tests.sh
```

Run a single runtime to validate setup:
```bash
bash tests/live/test-live-skill-recording.sh
```

Limit the matrix to one runtime:
```bash
SB_LIVE_RUNTIMES=claude bash tests/live/run-live-tests.sh
SB_LIVE_RUNTIMES=codex bash tests/live/run-live-tests.sh
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

Each runtime run uses:
- An isolated temp workspace directory (`mktemp -d`)
- Isolated state files: `~/.claude/.silver-bullet/live-test-state-{PID}`
- Isolated trivial files: `~/.claude/.silver-bullet/live-test-trivial-{PID}`
- For Codex-compatible runs, an isolated temporary `HOME`, `CODE_HOME`, and
  `CODEX_HOME` backed by Kay/MiniMax so the test installer never rewrites the
  user's real `~/.codex` hook cache.

The matrix runs Claude and Codex sequentially so they do not clobber each other's
shared SB state. All temp files are cleaned up after each scenario.
When the full Claude+Codex matrix passes, `run-live-tests.sh` writes the
session-scoped `release-live-matrix` marker (`matrix=full-claude-codex`) that
`completion-audit.sh` requires before `gh release create`.
If Claude usage is exhausted for a release session and the user explicitly
approves skipping further Claude live testing, run the matrix with
`SB_LIVE_RUNTIMES=codex` / `SB_E2E_LIVE_RUNTIMES=codex` and set
`SB_ALLOW_CODEX_ONLY_LIVE_RELEASE=1` so the release gate accepts the
`matrix=codex-only` markers for that session only.

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
