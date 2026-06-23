# Silver Bullet Live AI E2E Tests

These tests invoke the **real Kay-backed agent** with the Silver Bullet plugin
loaded and stored credentials. The standard path uses Kay's MiniMax.io
provider credentials with `MiniMax-M3` and low reasoning for isolated
live testing. They verify that SB enforcement hooks
(dev-cycle-check, record-skill, stop-check, compliance-status, forbidden-skill-check)
actually work when the live agent triggers them via real tool usage.

## Prerequisites

- Kay `v0.9.6` available in `PATH` for Kay-agent runs
- MiniMax.io credentials available through the user's Kay config
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
bash tests/live/test-live-review-fix-ladder-smoke.sh
```

Review fix ladder smoke (automated, no API cost — default):
```bash
bash tests/live/test-live-review-fix-ladder-smoke.sh
```

Optional one-turn live agent smoke:
```bash
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_RUNTIME=codex bash tests/live/test-live-review-fix-ladder-smoke.sh
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_RUNTIME=claude bash tests/live/test-live-review-fix-ladder-smoke.sh
```

Full model ladder live smoke (every resolver rung; real API cost per host):
```bash
# Codex native (/Applications/Codex.app/.../codex) — uses codex exec by default
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=codex \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh

# Claude Code CLI
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=claude \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh

# Cursor — in Cursor IDE Composer (auto-detects CURSOR_AGENT=1; no cursor-agent login needed)
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=cursor \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh

# Cursor headless via cursor-agent CLI (requires `cursor-agent login` or CURSOR_API_KEY)
SB_LIVE_CURSOR_IN_SESSION=0 SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=cursor \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh

# All hosts sequentially (Cursor falls back to resolver-only slug validation when not logged in and not in IDE)
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=all \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh
```

Useful tuning flags:
- `SB_LIVE_REVIEW_FIX_LADDER_MAX_RUNGS=2` — cap rungs for a cheaper escalation check
- `SB_LIVE_REVIEW_FIX_LADDER_CLEAN_PASSES=2` — require two consecutive clean passes per rung
- `SB_LIVE_REVIEW_FIX_LADDER_LITE_PROMPT=0` — use full skill/invoke-skill prompt (slower on Codex)
- `SB_LIVE_CODEX_USE_EXEC=0` — force interactive Codex path instead of `codex exec`
- `CODEX_INTERACTIVE_TIMEOUT=180` / `CLAUDE_INTERACTIVE_TIMEOUT=180` / `CURSOR_AGENT_TIMEOUT=180` — per-turn timeout
- `SB_LIVE_CURSOR_IN_SESSION=1` — force IDE in-session file protocol (auto when `CURSOR_AGENT=1`)
- `SB_LIVE_CURSOR_IN_SESSION=0` — force headless `cursor-agent` CLI path
- `SB_LIVE_CURSOR_SESSION_DIR=<path>` — override request/response directory (default: `<workspace>/.cursor-live-session`)

When running the full Cursor ladder inside Cursor IDE Composer, the harness writes
`request-*.json` prompts under the session directory and waits for matching
`response-*.json` files. The active agent (or `tests/live/lib/cursor-in-session-driver.sh`
for smoke validation) writes responses via `tests/live/lib/cursor-in-session-respond.sh`.

## Test Scenarios

| File | Scenarios | What it tests |
|------|-----------|---------------|
| test-live-enforcement.sh | S1-S4 | HARD STOP blocking, planning gate, forbidden skills, stop-check |
| test-live-skill-recording.sh | S5-S6 | Skill recording to state file, compliance-status output |
| test-live-full-scenario.sh | S7-S8 | Session initialization, abbreviated SDLC lifecycle |
| test-live-doc-scheme.sh | Doc scheme | Doc scaffolding, monthly knowledge/learnings updates, filename conventions |
| test-silver-init-migration.sh | Init docs bootstrap | `silver:init` Step 3.5.5 delegation to `silver:ensure-docs`, brownfield preserve-vs-switch, archive move/recovery paths |
| test-live-review-fix-ladder-smoke.sh | Review fix ladder | Resolver + invoke-skill + charter fixture (automated); optional one-turn live agent with `SB_LIVE_REVIEW_FIX_LADDER_LIVE=1` |
| test-live-review-fix-ladder-full-ladder.sh | Review fix ladder full ladder | Every resolver rung per host with `SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1`; Cursor in-session mode in IDE Composer; resolver-only fallback when headless and not authenticated |

## Isolation

Each agent run uses:
- An isolated temp workspace directory (`mktemp -d`)
- Isolated state files: `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/live-test-state-{PID}`
- Isolated trivial files: `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/live-test-trivial-{PID}`
- For Kay-agent runs, an isolated temporary `KAY_HOME` root backed by Kay's
  MiniMax.io provider path so the test installer never rewrites the user's
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
journey against the standalone sibling `todo-app` repo and also writes an `inline-e2e-matrix` marker so the release gate can
prove the end-user experience actually ran in this session. Both markers must
be present before a release can proceed.

The init-docs bootstrap scenario and review-fix-ladder smoke are separate
on-demand tests and are not part of the default `run-live-tests.sh` matrix.

## Not Included in Unit/Integration Suites

These tests are **NOT** included in `run-all-tests.sh`. Run them separately via
`run-live-tests.sh` when you need to validate real AI + hook integration.
