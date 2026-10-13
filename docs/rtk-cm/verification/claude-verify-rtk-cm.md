# Self-Verification: RTK + Context Mode in Claude Code (Global)

Machine-level audit for **Claude Code** — no Silver Bullet prerequisite.

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host claude`

---

## Phase 1 — Pre-flight

### 1.1 RTK binary

```bash
which rtk && rtk --version
rtk --help 2>&1 | head -3
rtk gain --help >/dev/null && echo OK-rtk-ai
```

**Pass:** version `0.42+`, first help lines mention token rewrite (not "Rust Type Kit").

**Fail:** `brew tap rtk-ai/rtk && brew install rtk`

### 1.2 Context Mode

```bash
node --version    # >= v22.5
which context-mode
```

**Pass:** The global Context Mode CLI is on PATH.

**Fail:** `npm install -g context-mode`

---

## Phase 2 — Global artifacts

### 2.1 RTK hook (`~/.codex/settings.json`)

```bash
jq '.hooks.PreToolUse[]? | select(.command? | test("rtk"))' ~/.codex/settings.json 2>/dev/null
grep -q rtk ~/.codex/settings.json 2>/dev/null && echo OK-settings
test -f ~/.codex/RTK.md && echo OK-rtk-md
```

**Pass:** RTK PreToolUse entry and `RTK.md` present.

**Fail:** `rtk init -g`

### 2.2 Context Mode shared MCP

```bash
jq '.mcpServers["context-mode"]' ~/.claude.json 2>/dev/null
test "$(jq -r '.enabledPlugins["context-mode@context-mode"] // false' ~/.claude/settings.json 2>/dev/null)" = false && echo OK-no-native-plugin
```

**Pass:** Shared `context-mode` MCP entry in `~/.claude.json` and no enabled native plugin.

**Fail:** `bash scripts/optimize-rtk-context-mode.sh --host claude`

### 2.3 Hook rewrite smoke test

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | rtk hook claude 2>/dev/null | jq -r '.updatedInput.command // .updated_input.command // empty'
```

**Pass:** output contains `rtk git status`.

**Fail:** re-run `rtk init -g`; restart Claude Code.

---

## Phase 3 — Doctor

```bash
CONTEXT_MODE_PLATFORM=claude context-mode doctor 2>&1 | grep -E 'PASS|FAIL|WARN' | head -20
```

Run the same shared executable from Claude's configured MCP entry; the terminal command above is the canonical doctor surface.

**Pass:** PreToolUse / PreCompact hooks PASS.

---

## Phase 4 — Live session (manual)

1. Restart Claude Code after wiring.
2. Ask: "Run `git status` and report output length."
3. Ask: "Call ctx_stats and report savings."

**Pass:** compressed git output; `ctx_stats` succeeds.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK binary (rtk-ai) | ✅ / ❌ |
| RTK settings.json hook | ✅ / ❌ |
| Context Mode plugin/MCP | ✅ / ❌ |
| `rtk hook claude` rewrite | ✅ / ❌ |
| Doctor / live session | ✅ / ❌ |

**Overall:** 🟢 all pass · 🟡 partial · 🔴 reinstall stack

## Known gaps

- `rtk gain` tracks global savings; Claude hook is in `settings.json` not `~/.cursor/hooks.json`.
- Restart required after plugin install.
