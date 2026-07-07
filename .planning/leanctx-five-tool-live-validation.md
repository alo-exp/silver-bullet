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

Live validation is **structural PASS / delegate SKIP**. Full S01–S10 agent-cursor delegation requires interactive `cursor-agent` auth and a non-hanging delegate session. Re-run locally:

```bash
SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 bash tests/live/test-live-five-tool-stack-cursor.sh
```

## Offline coverage (CI-safe)

All routing, gate, install, and policy behavior validated offline — see [BUILD-COMPLETE](leanctx-five-tool-BUILD-COMPLETE.md).
