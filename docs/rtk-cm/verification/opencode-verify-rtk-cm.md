# Self-Verification: RTK + Context Mode in OpenCode (Global)

Machine-level audit for **OpenCode** — no Silver Bullet prerequisite.

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host opencode`

**Config root:** `~/.config/opencode/opencode.json` (authoritative; `opencode.jsonc` is optional stub)

---

## Phase 1 — Pre-flight

```bash
which opencode 2>/dev/null || which oc 2>/dev/null
which rtk && rtk --version
which context-mode
node --version
```

**Pass:** OpenCode binary optional for config checks; RTK + CM CLIs required.

---

## Phase 2 — Global artifacts

### 2.1 RTK plugin

```bash
test -f ~/.config/opencode/plugins/rtk.ts && echo OK-rtk-plugin
jq -r '.plugin[]' ~/.config/opencode/opencode.json | grep -E 'rtk|plugins/rtk'
```

**Pass:** `rtk.ts` exists and listed in `plugin` array.

**Fail:** `rtk init -g --opencode`

### 2.2 Context Mode plugin + MCP

```bash
jq -r '.plugin[]' ~/.config/opencode/opencode.json | grep -x context-mode
jq '.mcp["context-mode"]' ~/.config/opencode/opencode.json
```

**Pass:** `context-mode` in plugin list; MCP block with `command` containing `context-mode`.

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

**Pass:** OpenCode adapter detected; plugin/MCP checks PASS.

---

## Phase 4 — Live session (manual)

1. Restart OpenCode after plugin changes.
2. Run `git status`, `ls` — RTK plugin rewrites via `tool.execute.before`.
3. Use `context-mode_ctx_execute` for a large analysis task.

**Pass:** compact shell output; ctx tools respond.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK plugin (`rtk.ts`) | ✅ / ❌ |
| CM plugin + MCP | ✅ / ❌ |
| AGENTS.md routing | ✅ / ❌ |
| Doctor | ✅ / ❌ |
| Live session | ✅ / ❌ |

**Overall:** 🟢 · 🟡 · 🔴

## Known gaps

- RTK OpenCode hook applies to **Bash tool only** — built-in file readers are not rewritten.
- OpenCode lacks real SessionStart; CM uses `experimental.chat.system.transform` surrogate.
- Plugin array uses string paths — preserve `./plugins/rtk.ts` when merging manually.
