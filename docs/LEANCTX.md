# LeanCTX — SB Recommended Tool (Five-Tool Parallel Stack)

Silver Bullet integrates [LeanCTX](https://leanctx.com/) as an opt-in recommended tool for **parallel-routed compression** alongside RTK, Context Mode, Graphify, and agentmemory. When opted in, LeanCTX owns specific compression surfaces; RTK and Context Mode remain in the catalog with **surface-level mutual exclusion** so overlapping paths never run concurrently.

See [`.planning/PLAN-leanctx-five-tool-integration.md`](../.planning/PLAN-leanctx-five-tool-integration.md) for the full conflict inventory (17 items) and implementation phases.

## Opt-In Policy

Consent lives in `.silver-bullet.json`:

```json
"recommended_tools": {
  "leanctx": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "required_when_enabled": true,
    "min_version": "3.9.9",
    "stack_mode": "parallel_routed",
    "optimization_profile": "five_tool_routed",
    "mcp_tool_prefix": "lctx_"
  }
}
```

| `enabled_by_user` | Behavior |
|-----------------|----------|
| `null` | Consent pending — SB prompts at init, update, session start |
| `true` | Mandatory when install succeeded — hooks require LeanCTX for owned surfaces |
| `false` | Advisory only — two-tool RTK + Context Mode stack unchanged |

**MCP namespace:** LeanCTX tools are registered with the `lctx_` prefix. Never register raw `ctx_*` from LeanCTX when Context Mode is opted in — SB merge scripts enforce this separation.

## Install

### CLI (all hosts)

```bash
curl -fsSL https://leanctx.com/install.sh | sh
lean-ctx --version
```

### SB host-aware install (library mode)

SB owns host config writes. Use library-mode init only — **never** full `lean-ctx init --agent *` (would clobber `.cursorrules`, `AGENTS.md`, or host settings).

| Host | Command |
|------|---------|
| Cursor | `bash scripts/install-leanctx-sb.sh --host cursor --project-root "$(pwd)"` |
| Claude Code | `bash scripts/install-leanctx-sb.sh --host claude --project-root "$(pwd)"` |
| Codex | `bash scripts/install-leanctx-sb.sh --host codex --project-root "$(pwd)"` |
| OpenCode | `bash scripts/install-leanctx-sb.sh --host opencode --project-root "$(pwd)"` |

> The SB installer owns the host config writes. It also records the resolved, user-global five-tool executable paths in `~/.silver-bullet/five-tool-stack/instances.json`; host adapters differ only in JSON/TOML syntax.

## Routing Table (`optimization_profiles.five_tool_routed`)

When LeanCTX is enabled, SB applies the `five_tool_routed` profile (extends `synergy_max`):

| SB route | Owner | Incumbent disabled on surface |
|----------|-------|-------------------------------|
| `sb_wire` | LeanCTX wire proxy + savings ledger | CM wire intercept |
| `sb_read` | LeanCTX `lctx_read_ast` | CM read-deny narrowed to `Read` only |
| `sb_grep` | Context Mode `ctx_execute` / `ctx_search` | Grep not intercepted by read-deny |
| `sb_shell` | RTK | LeanCTX shell rewrite OFF |
| `sb_slice` | Context Mode `ctx_execute` / `ctx_batch_execute` | LeanCTX sandbox MCP OFF |
| `sb_webfetch` | Context Mode (`CTX_FETCH_STRICT` deny → `ctx_fetch_and_index`) | LeanCTX fetch MCP OFF |
| `sb_graph` | Graphify `query` / `path` / `explain` | `lctx_graph` advisory-only |
| `sb_remember` | agentmemory `memory_save` | `lctx_remember` blocked |
| `sb_pathjail` | LeanCTX PathJail (physical rail) | Always on when LeanCTX enabled |
| `sb_injection` | LeanCTX injection detection | Always on when LeanCTX enabled |

LeanCTX MCP compatibility note: `lctx_read_ast` is Silver Bullet's logical
`sb_read` route name. Current LeanCTX releases expose the routed operation as
`ctx_read` on the `leanctx` server (for Cursor, `leanctx-ctx_read`), so live
scenario checks must use that server-qualified native name with a read mode;
they must not fall back to native `Read` for analysis.

**Primary FTS:** `context_mode` — LeanCTX FTS is disabled in parallel mode to avoid triple FTS5.

Registry helpers (Phase 1):

- `sb_stack_leanctx_active` — true when LeanCTX opted in and not suspended
- `sb_stack_surface_owner` — maps `Read`→`sb_read`→`leanctx`, `Grep`→`sb_grep`→`context_mode`, etc.

## Host Matrix

| Host | Wire + ledger | AST read | PathJail | Injection | RTK shell | CM sandbox | CM webfetch | Graphify | agentmemory | `lctx_graph` | `lctx_remember` | Notes |
|------|---------------|----------|----------|-----------|-----------|------------|-------------|----------|-------------|--------------|-----------------|-------|
| **Cursor** | ✅ LeanCTX | ✅ LeanCTX | ✅ | ✅ | ✅ RTK | ✅ CM | ✅ CM deny | ✅ Graphify | ✅ AM | ⚠️ advisory | ❌ blocked | Full five-tool routed stack |
| **Claude Code** | ✅ LeanCTX | ✅ LeanCTX | ✅ | ✅ | ✅ RTK | ✅ CM | ✅ CM deny | ✅ Graphify | ✅ AM | ⚠️ advisory | ❌ blocked | Hook chain verified in Phase 4 tests |
| **Codex** | ✅ LeanCTX | ❌ deny-only | ✅ | ✅ | ✅ RTK | ✅ CM | ✅ CM deny | ✅ Graphify | ✅ AM | ⚠️ advisory | ❌ blocked | AST blocked until PreToolUse rewrite; wire-proxy ordering validator mandatory |
| **OpenCode** | ✅ LeanCTX | ⚠️ verify install | ✅ | ✅ | ✅ RTK | ✅ CM | ✅ CM deny | ✅ Graphify | ✅ AM | ⚠️ advisory | ❌ blocked | AST support confirmed at install verify or documented gap |

### Cross-tool convergence (`cross_tool`)

`cross_tool` is supported on Claude Code, Codex, and Cursor. The reconciler uses each host's native configuration contract—Claude JSON/plugin settings, Codex TOML plus prompt-layer artifacts, and Cursor MCP/hooks—while all three resolve the same user-global five-tool executable profile. Codex remains deny-only for PreToolUse rewriting, so its AST read path has a platform limitation; that limitation does not make `cross_tool` unsupported. OpenCode remains outside the supported five-tool host matrix until its native convergence contract is added.

### Shared global five-tool instances

The three supported hosts must not drift onto separate package runners or binaries. SB writes one local manifest at `~/.silver-bullet/five-tool-stack/instances.json` with the resolved executable and arguments for Graphify, agentmemory, Context Mode, LeanCTX, and RTK. Cursor `mcp.json`, Claude `.claude.json`, and Codex `config.toml` preserve their native syntax but reference those same manifest-selected executables. If an optional Claude `context-mode@context-mode` plugin is enabled, the optimizer disables it before registering the shared Context Mode MCP entry, so Claude cannot launch a second Context Mode runtime. agentmemory uses the one local service at `http://localhost:3111`.

### Codex Limitations

Codex PreToolUse is **deny-only** — no `updatedInput` rewrite. When LeanCTX is enabled on Codex:

- **Wire proxy + ledger + PathJail + injection detection** run normally
- **AST read-path (`lctx_read_ast`)** is unavailable — RTK + Context Mode remain primary compressors for shell and analysis
- **LeanCTX shell and sandbox MCP** are explicitly OFF (RTK and CM own those surfaces)
- Install-time **wire-proxy JSON message ordering** is validated by `scripts/lib/verify-leanctx-wire-proxy-ordering.py` (Phase 2)

## Deep-Research Fetch Routing

For `silver:deep-research`, use **search_cli first** when configured. LeanCTX fetch is for **non-research flows only** — avoids overlap with search_cli breadth providers. See `skills/deep-research/SKILL.md`.

## Verification

Phase 1 (config/registry only):

```bash
jq '.recommended_tools.leanctx' .silver-bullet.json
jq '.optimization_profiles.five_tool_routed.routes' .silver-bullet.json
bash tests/scripts/test-recommended-tools-policy.sh
```

Phase 2+ (hooks/install):

```bash
bash scripts/optimize-five-tool-stack.sh --apply
bash scripts/optimize-five-tool-stack.sh --verify
bash scripts/enable-rtk-context-mode.sh
```

## Recovery (stack compression mutex)

When the five-tool coordinator records `sb_stack_double_compression`, PreToolUse may block until the mutex clears. State is **global** under `${SB_RUNTIME_STATE_DIR:-~/.silver-bullet}/stack-compression-mutex` — not per-session; **subagents cannot bypass** a dirty mutex in the parent runtime home.

**Self-heal:** Complete one **compliant routed-owner** tool call on the owned surface (for example `ctx_search` for `sb_slice`, `lctx_read_ast` for `sb_read`, or RTK-compressed Bash without LeanCTX shell rewrite for `sb_shell`). The coordinator clears the entire mutex on success.

**Manual escape hatches:**

1. `/silver:clear-stack-state` — documents and runs clear + optional agentmemory scaffold
2. `bash scripts/sb-doctor.sh --fix` — clears mutex (check **D20**) and scaffolds `.agentmemory/memory` when agentmemory is opted in
3. Last resort: `rm -f "${SB_RUNTIME_STATE_DIR:-$HOME/.silver-bullet}/stack-compression-mutex"` (no audit trail)

**Wedged-session warning:** When the mutex is dirty, do not trust prior tool success self-reports — re-run verification after recovery.

**Install guard:** `install-leanctx-sb.sh` / `optimize-five-tool-stack.sh` write `LEANCTX_DISABLE_SHELL_MCP=1` in the five-tool profile env so RTK owns `sb_shell` without LeanCTX shell MCP overlap.

## Durable file edits (compression marker leak)

LeanCTX `ctx_read` returns **display-only** compression markers (`[lean-ctx: omitted N lines]`, `filename [194L]` headers). These must never be written back to disk.

| Phase | Tool | Mode |
|-------|------|------|
| Orient / analyze | `ctx_read`, `lctx_read_ast` | compressed modes OK |
| Write / Edit / patch | native `Read` or `ctx_read(raw=true)` | **required** |

**Upstream (v3.9.9+):** LeanCTX PreToolUse `handle_deny()` blocks Write/Edit/StrReplace/MultiEdit payloads containing `[lean-ctx:` markers ([yvgude/lean-ctx#805](https://github.com/yvgude/lean-ctx/issues/805)). Escape hatch: `LEAN_CTX_ALLOW_COMPRESSED_WRITE=1`.

**SB belt-and-suspenders:** `hooks/compression-marker-guard.sh` remains in the SB plugin hook chain — it also catches ctx_read file headers (`filename.plan.md [316L]`) and covers hosts where only SB plugin hooks are active. Upgrade: `lean-ctx update` or `curl -fsSL https://leanctx.com/install.sh | sh` (requires **≥ 3.9.9**).

## Related Docs

- [LEANCTX-OPERATING-GUIDE.md](LEANCTX-OPERATING-GUIDE.md) — practical routing, execution, timeout, and edit-safety playbook
- [RTK.md](RTK.md) — shell compression (`sb_shell`)
- [CONTEXT-MODE.md](CONTEXT-MODE.md) — sandbox, webfetch, grep analysis (`sb_slice`, `sb_webfetch`, `sb_grep`)
- [GRAPHIFY.md](GRAPHIFY.md) — code retrieval (`sb_graph`)
- [AGENTMEMORY.md](AGENTMEMORY.md) — session capture (`sb_remember`)
- [STACK-OPTIMIZATION.md](STACK-OPTIMIZATION.md) — Graphify + agentmemory synergy profile

## MCP namespace and reload receipts

LeanCTX registers as `leanctx` with `lctx_*` tool prefix. Overlapping `ctx_*` sandbox/fetch/shell tools are disabled when Context Mode and RTK are active. MCP merge is atomic via `patch-mcp.py`; reload receipts track affected servers per worktree. Cross-worktree receipts never supersede each other.
