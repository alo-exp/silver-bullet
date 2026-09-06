# Self-Verification: RTK + Context Mode in Pi (Global)

Machine-level audit for **Pi** — no Silver Bullet project opt-in is required for the standalone stack, but the SB adapter is the canonical wiring used by the five-tool profile.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host pi --project-root "$(pwd)"`

**Config root:** `~/.pi/agent/` (override with `PI_CODING_AGENT_DIR`)

## Phase 1 — Pre-flight

```bash
pi --version
pi list
rtk --version
rtk gain --help
context-mode --version
node --version
```

**Pass:** Pi is available; `rtk gain --help` succeeds; Context Mode runs on the supported Node version.

## Phase 2 — Shared stack artifacts

```bash
MANIFEST="${HOME}/.silver-bullet/five-tool-stack/instances.json"
ADAPTER="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/silver-bullet-five-tool-stack"
jq -e '.scope == "user-global" and .profile == "five_tool_routed"' "$MANIFEST"
jq -e '.servers.graphify.enabled and .servers.context_mode.enabled and .servers.leanctx.enabled and .servers.rtk.enabled' "$ADAPTER/config.json"
jq -e '.routeShell == false and .enableMcp == true and (.disableTools | index("ctx_shell")) != null' \
  "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/pi-lean-ctx/config.json"
grep -q 'silver-bullet-five-tool-stack' "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/settings.json"
```

**Pass:** the adapter, Pi settings, and `pi-lean-ctx` all point at one manifest; native Pi Bash remains available for the RTK `tool_call` adapter while LeanCTX's overlapping shell MCP is disabled.

## Phase 3 — Native tool checks

Run a fresh non-interactive Pi session with the configured provider/model:

```bash
pi -p --provider omniroute --model opencode-go/minimax-m3 \
  "Call sb_context_execute exactly once with language python and code print('PI_CONTEXT_TOOL_OK'), then reply PI_CONTEXT_TOOL_DONE."
```

Then repeat with `sb_graphify_query` and `memory_health`. Use the native `ctx_read` tool for a bounded file read; Pi's local LeanCTX extension may expose that tool without an `lctx_` display prefix.

**Pass:** Context Mode, Graphify, agentmemory, and LeanCTX each return successfully with no extension load errors.

## Phase 4 — RTK shell ownership

```bash
pi -p --provider omniroute --model opencode-go/minimax-m3 \
  "Use the bash tool exactly once with command 'git status'. Then reply PI_RTK_BASH_DONE."
```

**Pass:** the session completes; the adapter's `tool_call` handler invokes the manifest-selected RTK binary before native Bash. A direct `rtk rewrite git status` check should return `rtk git status`.

## Verdict

| Check | Result |
|-------|--------|
| Global manifest | ✅ / ❌ |
| Pi adapter + settings | ✅ / ❌ |
| Context Mode native bridge | ✅ / ❌ |
| Graphify MCP | ✅ / ❌ |
| agentmemory extension | ✅ / ❌ |
| LeanCTX bridge | ✅ / ❌ |
| RTK native Bash adapter | ✅ / ❌ |

**Overall:** 🟢 · 🟡 · 🔴

## Known gaps

- Pi has no native `mcp` subcommand; the SB extension and `pi-lean-ctx` package provide the native bridge.
- Pi provider names are installation-specific; on this workstation the available route is `--provider omniroute --model opencode-go/minimax-m3`.
- Pi's local LeanCTX tools may retain native `ctx_*` names; the `lctx_` prefix applies to the LeanCTX MCP bridge namespace and overlap policy.
