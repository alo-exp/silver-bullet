# Five-Tool Stack — Pre-Release Live Gate

Mandatory pre-release validation for the parallel-routed five-tool stack (LeanCTX + RTK + Context Mode + Graphify + agentmemory) when `recommended_tools.leanctx.enabled_by_user` is `true`.

## When it runs

| Path | Trigger | Live delegate |
|------|---------|---------------|
| CI (`tests/run-all-tests.sh`) | [`test-five-tool-prerelease-cursor.sh`](../scripts/test-five-tool-prerelease-cursor.sh) in Script Unit Tests | **Offline only** (leanctx usually not opted in) |
| Pre-release (`scripts/pre-release-gate.sh`) | Stage 4c after site freshness, before full suite | **Required** when leanctx opted in + cursor-agent auth |
| Manual optional | `SB_FIVE_TOOL_LIVE=1` in `run-all-tests.sh` | Operator choice |

## Release engineer commands

### Standard pre-release (includes five-tool when leanctx enabled)

```bash
bash scripts/pre-release-gate.sh
```

When `.silver-bullet.json` has `recommended_tools.leanctx.enabled_by_user: true`, the gate sets:

- `SB_FIVE_TOOL_PRERELEASE=1`
- `SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1`

and runs the live Cursor delegate scenarios (S01, S02, S04, S06, S09).

### LeanCTX opted in — explicit live run

```bash
export CURSOR_API_KEY=...   # or cursor-agent login
SB_FIVE_TOOL_PRERELEASE=1 SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1 \
  bash tests/scripts/test-five-tool-prerelease-cursor.sh
```

### Full 10-scenario matrix (post-release diagnostics)

```bash
SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full \
  SB_FIVE_TOOL_SCENARIO_TIMEOUT=600 \
  bash tests/live/test-live-five-tool-stack-cursor.sh
```

### Skeleton / wiring only (no delegate)

```bash
bash tests/live/test-live-five-tool-stack-cursor.sh
```

## Harness

- Skill route: `/silver:agent-cursor` — [`skills/silver-agent-cursor/SKILL.md`](../../skills/silver-agent-cursor/SKILL.md)
- Delegate wrapper: [`scripts/agent-cursor-delegate.sh`](../../scripts/agent-cursor-delegate.sh)
- Scenario matrix: [`tests/skill-scenarios/silver-five-tool-stack.md`](../../tests/skill-scenarios/silver-five-tool-stack.md)
- Live runner: [`tests/live/test-live-five-tool-stack-cursor.sh`](../../tests/live/test-live-five-tool-stack-cursor.sh)

## Pass criteria

### Offline (always mandatory)

Hook and script bundle in [`tests/scripts/lib/five-tool-prerelease.sh`](../scripts/lib/five-tool-prerelease.sh) must be green, plus structural wiring checks (delegate script, skill, claims registry, pre-release-gate hook).

### Live pre-release (mandatory when leanctx opted in)

| Scenario | Validates |
|----------|-----------|
| S01 | Five-tool opt-in + `install-leanctx-sb.sh --dry-run` + `lctx_` MCP prefix |
| S02 | LeanCTX AST read path (`lctx_read_ast`) |
| S04 | RTK shell once, no LeanCTX double-wrap |
| S06 | `graphify query` + `memory_save`; `lctx_remember` blocked |
| S09 | `sb_stack_double_compression` deny on conflict regression |

Each scenario uses per-scenario timeout (`SB_FIVE_TOOL_SCENARIO_TIMEOUT`, default 180s). Timeout → **FAIL**, not hang.

### Skip vs fail

| Condition | CI (no leanctx) | Pre-release (leanctx on) |
|-----------|-----------------|--------------------------|
| cursor-agent missing | SKIP (offline pass) | **FAIL** |
| cursor-agent not authenticated | SKIP | **FAIL** |
| Scenario timeout | FAIL | **FAIL** |
| Delegate exit non-zero | FAIL | **FAIL** |

## Success marker

On success, writes:

`${SB_RUNTIME_STATE_DIR}/pre-release-five-tool-stack`

## Registry

Claim `five-tool-stack-cursor` in [`pre-release-claims-registry.json`](pre-release-claims-registry.json).

## Related docs

- [`.planning/PLAN-leanctx-five-tool-integration.md`](../../.planning/PLAN-leanctx-five-tool-integration.md)
- [`docs/LEANCTX.md`](../LEANCTX.md)
- [`docs/internal/pre-release-quality-gate.md`](../internal/pre-release-quality-gate.md)
