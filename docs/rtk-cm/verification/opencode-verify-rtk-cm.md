# Self-Verification: RTK + Context Mode in OpenCode (Global)

Machine-level audit for **OpenCode** — no Silver Bullet prerequisite.

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host opencode --project-root "$(pwd)"`

**Config root:** `~/.config/opencode/opencode.json` (authoritative; `opencode.jsonc` is optional stub)

---

## Phase 1 — Pre-flight

```bash
which opencode 2>/dev/null || which oc 2>/dev/null
which rtk && rtk --version
which context-mode
node --version
```

**Pass:** OpenCode binary optional for config checks; RTK + CM CLIs required, and the shared five-tool manifest is present.

---

## Phase 2 — Global artifacts

### 2.1 RTK plugin

```bash
test -f ~/.config/opencode/plugins/rtk.ts && echo OK-rtk-plugin
jq -r '.plugin[]' ~/.config/opencode/opencode.json | grep -E 'rtk|plugins/rtk'
grep -q '/.local/bin/rtk\|/bin/rtk' ~/.config/opencode/plugins/rtk.ts
```

**Pass:** `rtk.ts` exists and listed in `plugin` array.

**Fail:** an OpenCode plugin that calls a PATH-selected or host-local RTK binary instead of the shared manifest-selected executable.

### 2.2 Context Mode plugin (no legacy MCP)

```bash
CM_COMMAND="$(jq -r '.tools.context_mode.command' ~/.silver-bullet/five-tool-stack/instances.json)"
CM_PLUGIN="file://$(dirname "$CM_COMMAND")/build/adapters/opencode/plugin.js"
jq -e --arg expected "$CM_PLUGIN" \
  '.plugin | any(.[]?; . == $expected or . == "context-mode")' \
  ~/.config/opencode/opencode.json >/dev/null
! jq -e '.mcp["context-mode"] // .mcp["user-context-mode"]' ~/.config/opencode/opencode.json >/dev/null
```

**Pass:** the manifest-backed Context Mode plugin is the sole Context Mode owner and no legacy `mcp.context-mode` block remains.

**Fail:** `bash scripts/optimize-rtk-context-mode.sh --host opencode`

### 2.3 Routing instructions (`AGENTS.md`)

```bash
test -f ~/.config/opencode/AGENTS.md && grep -q context-mode ~/.config/opencode/AGENTS.md && echo OK
```

**Fail:** `bash scripts/install-recommended-tools-global.sh --host opencode`

---

## Phase 3 — Doctor

```bash
CONTEXT_MODE_PLATFORM=opencode context-mode doctor 2>&1 | grep -E 'PASS|FAIL|WARN' | head -20
```

**Pass:** OpenCode adapter detected; native Context Mode plugin and non-duplicate MCP checks PASS.

---

## Phase 4 — Live session (manual)

1. Restart OpenCode after plugin changes.
2. Run `git status`, `ls` — RTK plugin rewrites via `tool.execute.before`.
3. Use OpenCode's native Context Mode `ctx_execute` tool for a large analysis task.

**Pass:** compact shell output; ctx tools respond.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK plugin (`rtk.ts`) | ✅ / ❌ |
| CM native plugin; no duplicate MCP | ✅ / ❌ |
| AGENTS.md routing | ✅ / ❌ |
| Doctor | ✅ / ❌ |
| Live session | ✅ / ❌ |

**Overall:** 🟢 · 🟡 · 🔴

## Known gaps

- RTK OpenCode hook applies to **Bash tool only** — built-in file readers are not rewritten.
- OpenCode lacks real SessionStart; CM uses `experimental.chat.system.transform` surrogate.
- Plugin array uses package/file paths — preserve the manifest-backed Context Mode entry and `./plugins/rtk.ts` when merging manually.
- OpenCode qualifies some MCP tools by server name (for example `leanctx_ctx_read`); this is native naming and does not indicate a second LeanCTX instance.
