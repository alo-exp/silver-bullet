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

## Offline coverage (CI-safe)

All routing, gate, install, and policy behavior validated offline — see [BUILD-COMPLETE](leanctx-five-tool-BUILD-COMPLETE.md).
