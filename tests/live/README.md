# Silver Bullet Live AI E2E Tests

These tests invoke the **real agent** (Claude by default; `SB_LIVE_RUNTIMES` selects `claude`,
`codex` or `kay`) with the Silver Bullet plugin loaded and stored credentials. The Kay path uses
Kay's MiniMax.io provider credentials with `MiniMax-M3` and low reasoning for isolated live testing. They verify that SB enforcement hooks
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

Run the default suite (Claude runtime):
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

# All hosts sequentially
SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=all \
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh
```

Useful tuning flags:
- `SB_LIVE_REVIEW_FIX_LADDER_MAX_RUNGS=2` — cap rungs for a cheaper escalation check
- `SB_LIVE_REVIEW_FIX_LADDER_CLEAN_PASSES=2` — require two consecutive clean passes per rung
- `SB_LIVE_REVIEW_FIX_LADDER_LITE_PROMPT=0` — use full skill/invoke-skill prompt (slower on Codex)
- `SB_LIVE_CODEX_USE_EXEC=0` — force interactive Codex path instead of `codex exec`
- `CODEX_INTERACTIVE_TIMEOUT=180` / `CLAUDE_INTERACTIVE_TIMEOUT=180` — per-turn timeout

## Test Scenarios

| File | Scenarios | What it tests |
|------|-----------|---------------|
| test-live-enforcement.sh | S1-S3 | HARD STOP blocking (hook audit entry from the live turn), planning gate allow, forbidden-skill deny |
| test-live-skill-recording.sh | S5-S6 | Skill recording to state file, compliance-status output |
| test-live-full-scenario.sh | S7-S8 | Session initialization (SessionStart stamp), abbreviated SDLC lifecycle |
| test-live-doc-scheme.sh | Doc scheme | Doc scaffolding, monthly knowledge/learnings updates, filename conventions |
| test-silver-init-migration.sh | Init docs bootstrap | `sb:init` Step 3.5.5 delegation to `sb:ensure-docs`, brownfield preserve-vs-switch, archive move/recovery paths |
| test-live-review-fix-ladder-smoke.sh | Review fix ladder | Resolver + invoke-skill + charter fixture (automated); optional one-turn live agent with `SB_LIVE_REVIEW_FIX_LADDER_LIVE=1` |
| test-live-review-fix-ladder-full-ladder.sh | Review fix ladder full ladder | Every resolver rung per host with `SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1`|

## Isolation

Each scenario run uses:
- An isolated temp workspace directory (`mktemp -d`)
- Per-run state and branch files (`state-live-test-<pid>`, `branch-live-test-<pid>` under the runtime
  state dir), handed to the nested agent through `SILVER_BULLET_STATE_FILE` / `SILVER_BULLET_BRANCH_FILE`,
  so the operator's own `state` and `branch` files are never touched. The `trivial` marker and
  `mcp-needs-auth-cache.json` are still the operator's real files: `live_setup` backs them up and arms an
  `EXIT` trap that restores them even when a scenario aborts.
- Release evidence (`release-live-matrix`, `e2e-live-matrix`, `inline-e2e-matrix`, `quality-gate-state`,
  `verify-tests-state`) is snapshotted by the runner (`tests/live/lib/evidence-guard.sh`); on every exit a file
  that a live session's SessionStart reset removed is put back, while evidence that exists then is never
  overwritten or deleted. A snapshot left by a killed runner is recovered by the next start.
- For Kay-agent runs, an isolated temporary `KAY_HOME` root backed by Kay's
  MiniMax.io provider path so the test installer never rewrites the user's
  real `~/.codex` hook cache. Isolated homes are torn down on every exit.
- Native Codex isolated runs use Codex's supported
  `--dangerously-bypass-hook-trust` flag and auto-accept the one-time hook
  review inside the temporary isolated home only, so the live harness tests
  actual hook delivery without depending on forged private trust hashes or
  touching the user's real trust state.
- Kay isolated runs auto-accept the one-time hook review inside the temporary
  isolated home only, so the persisted trust state stays local to that temp
  tree and never touches the user's real config.

Passes are earned: a scenario passes on a hook audit entry written during the agent's turn, or on the
well-formed JSON a shipped hook returns for a real payload. A regex over the agent's reply, an empty
hook output or an unchanged file is not evidence.

The matrix can run multiple adapters sequentially for ad hoc diagnostics. The default runtime is
`claude`; when it passes, `run-live-tests.sh` writes the session-scoped `release-live-matrix` marker
(`matrix=claude-only`) that `completion-audit.sh` requires before `gh release create`
(`matrix=codex-only` for `codex`/`kay` alone, `matrix=full-claude-codex` for both families). The marker
is written only after every suite passed, from the runner's exit trap.

Captured Kay/Codex transcripts are written (mode 0600, redacted) to the isolated home's `.sb-transcripts/`
directory, or to `$CODEX_TRANSCRIPT_DIR` when set, never to the checkout. `tests/live/agents/*/transcripts/`
is gitignored as a safety net. They are separate from the official agent session stores that `silver-scan`
reads.

The separate todo-app suite at `tests/e2e-live/run-e2e-live-tests.sh` writes a
matching `e2e-live-matrix` marker. By default it runs the hook-failure matrix;
with `SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1` it also runs the inline full-surface
journey against the standalone sibling `todo-app` repo, and only then writes the
`inline-e2e-matrix` marker, so that marker proves the journey actually ran.
The release gate needs all three markers; the Claude supervised enterprise matrix does not write a
marker the gate accepts today.

The init-docs bootstrap scenario and review-fix-ladder smoke are separate
on-demand tests and are not part of the default `run-live-tests.sh` matrix.

## Not Included in Unit/Integration Suites

These tests are **NOT** included in `run-all-tests.sh`. Run them separately via
`run-live-tests.sh` when you need to validate real AI + hook integration.
