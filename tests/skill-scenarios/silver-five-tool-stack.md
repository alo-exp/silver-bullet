# Silver Five-Tool Stack — Live Scenario Matrix

## Skill: silver-five-tool-stack
## Context: Parallel routed 5-stack (LeanCTX + RTK + Context Mode + Graphify + agentmemory)
## Harness: [`tests/live/test-live-five-tool-stack-cursor.sh`](../live/test-live-five-tool-stack-cursor.sh) via [`/silver:agent-cursor`](../../skills/silver-agent-cursor/SKILL.md)

Plan reference: [`.planning/PLAN-leanctx-five-tool-integration.md`](../../.planning/PLAN-leanctx-five-tool-integration.md) Phase 4.

| # | Scenario | Acceptance | Ledger |
|---|----------|------------|--------|
| S01 | Opt-in all five tools in temp project | Install script exits 0; MCP JSON valid; `lctx_` prefix confirmed | pending |
| S02 | Read large file | LeanCTX AST path used; CM read-deny not triggered incorrectly on Read routing | pending |
| S03 | Grep for analysis | CM cooperative path (`ctx_execute`/`ctx_search`); read-deny does not intercept Grep when LeanCTX active | pending |
| S04 | Shell `git status` | RTK rewrite once; no LeanCTX second wrap | pending |
| S05 | WebFetch attempt | CM deny fires; LeanCTX fetch MCP not invoked | pending |
| S06 | `graphify query` + `memory_save` | Graphify/agentmemory gates pass; coordinator blocks `lctx_remember` | pending |
| S07 | Wire proxy smoke | Ledger records session entry; wire-proxy ordering validator passes | pending |
| S08 | PathJail + injection | Session log at `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/leanctx-session.log` contains PathJail allow + injection scan within 60s of agent turn | pending |
| S09 | Conflict regression | Coordinator returns `permission: deny` with `sb_stack_double_compression` when RTK-rewritten Bash re-offered to LeanCTX shell; same for CM-denied WebFetch → LeanCTX fetch MCP | pending |
| S10 | PreCompact lifecycle | Ordering preserved: CM PreCompact → AM snapshot → LeanCTX compact → stop-check | pending |

## Offline coverage (always in CI)

| Test | Validates |
|------|-----------|
| [`tests/hooks/test-leanctx-gate-lib.sh`](../hooks/test-leanctx-gate-lib.sh) | Gate helpers, TTL, install status |
| [`tests/hooks/test-leanctx-gate.sh`](../hooks/test-leanctx-gate.sh) | PreToolUse block when usage stale |
| [`tests/hooks/test-stack-compression-coordinator.sh`](../hooks/test-stack-compression-coordinator.sh) | Surface routing, Grep passthrough, double-wrap |
| [`tests/hooks/test-five-tool-mcp-namespace.sh`](../hooks/test-five-tool-mcp-namespace.sh) | MCP `lctx_` prefix; no duplicate `ctx_*` |
| [`tests/hooks/test-five-tool-mutual-exclusion.sh`](../hooks/test-five-tool-mutual-exclusion.sh) | RTK shell + `lctx_*` MCP blocks |
| [`tests/scripts/test-install-leanctx-sb.sh`](../scripts/test-install-leanctx-sb.sh) | Dry-run install; no config clobber |
| [`tests/scripts/test-optimize-five-tool-stack.sh`](../scripts/test-optimize-five-tool-stack.sh) | Profile apply idempotency |
| [`tests/hooks/test-agentmemory-graphify-synergy.sh`](../hooks/test-agentmemory-graphify-synergy.sh) | GX+AM synergy unchanged when LeanCTX present/disabled |

## Running live suite

```bash
SB_FIVE_TOOL_LIVE=1 bash tests/live/test-live-five-tool-stack-cursor.sh
```

Skips automatically when `cursor-agent` is missing or unauthenticated (documents skip reason in output).

## Host matrix notes

- **Cursor:** mandatory live path above.
- **Claude / Codex / OpenCode:** offline hook tests + enterprise matrix; Codex wire-proxy validator is install-time gate.
- **Codex AST read:** deny-only until PreToolUse rewrite lands upstream.
