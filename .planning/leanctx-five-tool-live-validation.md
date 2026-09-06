# LeanCTX Five-Tool Stack — Live Validation

**Date:** 2026-07-07  
**Harness:** [`tests/live/test-live-five-tool-stack-cursor.sh`](../tests/live/test-live-five-tool-stack-cursor.sh)  
**Scenario matrix:** [`tests/skill-scenarios/silver-five-tool-stack.md`](../tests/skill-scenarios/silver-five-tool-stack.md)

## Skeleton run (default)

```bash
SB_FIVE_TOOL_LIVE=1 bash tests/live/test-live-five-tool-stack-cursor.sh
```

| Result | Count |
|--------|-------|
| PASS | 3 |
| FAIL | 0 |
| SKIP | 1 |

**Passed checks**

- `agent-cursor-delegate.sh` present
- Scenario doc present
- Scenario doc lists 10 scenarios (S01–S10)

**Skip reason**

- Skeleton mode — `SB_FIVE_TOOL_LIVE_EXECUTE` not set (by design; structural gate only)

## Full delegate run (attempted)

```bash
SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 bash tests/live/test-live-five-tool-stack-cursor.sh
```

| Result | Status |
|--------|--------|
| S01–S10 delegate scenarios | **SKIP** — hung >5 min on first `agent-cursor-delegate.sh` invocation; process killed |

**Environment**

- `cursor-agent` on PATH: `/Users/shafqat/.local/bin/cursor-agent`
- `agent` alias on PATH: `/Users/shafqat/.local/bin/agent`
- Auth: not verified (skeleton did not require auth check before skip)

**Conclusion**

Live validation: **S01 PASS** with timeout fix (`CURSOR_AGENT_TIMEOUT` aligned to scenario timeout). S02+ may still exceed budget on slow delegate — use `SB_FIVE_TOOL_SCENARIO_TIMEOUT=180` and `SB_FIVE_TOOL_MODE=prerelease` for release gate subset.

Pre-release gate wired: `scripts/pre-release-gate.sh` Stage 4c → `tests/scripts/test-five-tool-prerelease-cursor.sh`.

Re-run locally:

```bash
SB_FIVE_TOOL_PRERELEASE=1 SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1 \
  bash tests/scripts/test-five-tool-prerelease-cursor.sh
```

## Resumed live validation (2026-09-05)

The adapter and harness fixes were validated against the real Cursor surface:

- S01 completed successfully with the isolated five-tool fixture.
- S02 completed successfully using the logical `lctx_read_ast` route mapped to
  Cursor's current `leanctx-ctx_read` (`ctx_read`) operation, followed by the
  Context Mode Grep route.
- S09 completed successfully and confirmed the coordinator's
  `sb_stack_double_compression` deny regression through `context-mode-ctx_execute`.
- S04 and S06 completed successfully in earlier live attempts before the
  account quota was exhausted.
- A complete five-scenario rerun reached S01 and S02, then S04/S06/S09 returned
  Cursor's Composer 2.5 `ActionRequiredError` usage-limit response; none of
  those scenarios timed out. The gate remains **quota-blocked**, not green.

The harness now keeps delegate logs outside the model-visible fixture, uses a
bounded outer watchdog, isolates Cursor config/data roots, exposes the source
checkout through `--add-dir` and `LEAN_CTX_EXTRA_ROOTS`, and cleans up orphaned
MCP/LSP children after quota or transport errors.

## Offline coverage (CI-safe)

All routing, gate, install, and policy behavior validated offline — see [BUILD-COMPLETE](leanctx-five-tool-BUILD-COMPLETE.md).
